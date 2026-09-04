package com.fiscalia.file_cast.scrcpy

import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/** Writes the encoded H.264 packets already received from scrcpy into MP4. */
class ScrcpyRecorder(
    private val outputFile: File,
    private val width: Int,
    private val height: Int,
) {
    companion object {
        private const val FLAG_CONFIG = Long.MIN_VALUE
        private const val FLAG_KEY_FRAME = 1L shl 62
        private const val PTS_MASK = (1L shl 62) - 1
    }

    private var muxer: MediaMuxer? = null
    private var trackIndex = -1
    private var started = false
    private var waitingForKeyFrame = true
    private var firstPtsUs = -1L
    private var lastPtsUs = -1L
    private var sampleCount = 0
    private val bufferInfo = MediaCodec.BufferInfo()

    @Synchronized
    fun start(codecConfig: ByteArray) {
        check(!started) { "La grabación ya está activa" }
        outputFile.parentFile?.mkdirs()
        val mediaMuxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
            val configUnits = splitAnnexB(codecConfig)
            val sps = configUnits.lastOrNull { nalType(it) == 7 }
                ?: throw IllegalStateException("La configuración H.264 no contiene SPS")
            val pps = configUnits.lastOrNull { nalType(it) == 8 }
                ?: throw IllegalStateException("La configuración H.264 no contiene PPS")
            format.setByteBuffer("csd-0", ByteBuffer.wrap(sps))
            format.setByteBuffer("csd-1", ByteBuffer.wrap(pps))
            trackIndex = mediaMuxer.addTrack(format)
            mediaMuxer.start()
            muxer = mediaMuxer
            started = true
        } catch (error: Exception) {
            try { mediaMuxer.release() } catch (_: Exception) {}
            outputFile.delete()
            throw error
        }
    }

    @Synchronized
    fun writePacket(headerValue: Long, payload: ByteArray) {
        if (!started || (headerValue and FLAG_CONFIG) != 0L) return
        val isKeyFrame = (headerValue and FLAG_KEY_FRAME) != 0L
        if (waitingForKeyFrame && !isKeyFrame) return
        waitingForKeyFrame = false
        val pts = headerValue and PTS_MASK
        if (firstPtsUs < 0) firstPtsUs = pts
        val normalizedPtsUs = (pts - firstPtsUs).coerceAtLeast(0)
        bufferInfo.set(
            0,
            payload.size,
            normalizedPtsUs,
            if (isKeyFrame) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0,
        )
        muxer?.writeSampleData(trackIndex, ByteBuffer.wrap(payload), bufferInfo)
        lastPtsUs = normalizedPtsUs
        sampleCount++
    }

    @Synchronized
    fun stop(): File {
        val activeMuxer = muxer
        var failure: Exception? = null
        try {
            check(started) { "El grabador no estaba iniciado" }
            val muxerToStop = checkNotNull(activeMuxer) { "MediaMuxer no estaba disponible" }
            check(sampleCount > 0) { "No se recibió un keyframe para crear el video" }
            bufferInfo.set(
                0,
                0,
                lastPtsUs + 33_333L,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
            )
            muxerToStop.writeSampleData(trackIndex, ByteBuffer.allocate(0), bufferInfo)
            muxerToStop.stop()
        } catch (error: Exception) {
            failure = error
        } finally {
            try { activeMuxer?.release() } catch (_: Exception) {}
            muxer = null
            started = false
        }
        if (failure != null || !outputFile.isFile || outputFile.length() == 0L) {
            outputFile.delete()
            throw IllegalStateException("No se pudo finalizar un MP4 válido", failure)
        }
        return outputFile
    }

    @Synchronized
    fun abort() {
        try { muxer?.release() } catch (_: Exception) {}
        muxer = null
        started = false
        outputFile.delete()
    }

    fun file(): File = outputFile

    private fun splitAnnexB(data: ByteArray): List<ByteArray> {
        val starts = mutableListOf<Int>()
        var index = 0
        while (index <= data.size - 4) {
            if (data[index] == 0.toByte() && data[index + 1] == 0.toByte() &&
                ((data[index + 2] == 1.toByte()) ||
                    (data[index + 2] == 0.toByte() && data[index + 3] == 1.toByte()))) {
                starts += index
                index += if (data[index + 2] == 1.toByte()) 3 else 4
            } else index++
        }
        if (starts.isEmpty()) return emptyList()
        return starts.mapIndexed { position, start ->
            data.copyOfRange(start, if (position + 1 < starts.size) starts[position + 1] else data.size)
        }
    }

    private fun nalType(unit: ByteArray): Int {
        var index = 0
        while (index < unit.size && unit[index] == 0.toByte()) index++
        if (index < unit.size && unit[index] == 1.toByte()) index++
        return if (index < unit.size) unit[index].toInt() and 0x1F else -1
    }
}
