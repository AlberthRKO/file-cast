package com.fiscalia.file_cast.scrcpy

import android.media.MediaCodec
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
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
    private var lastSampleDurationUs = 33_333L
    private var sampleCount = 0
    private val bufferInfo = MediaCodec.BufferInfo()
    private val temporaryFile = File("${outputFile.absolutePath}.part")

    @Synchronized
    fun start(codecConfig: ByteArray) {
        check(!started) { "La grabación ya está activa" }
        outputFile.parentFile?.mkdirs()
        if (temporaryFile.exists()) temporaryFile.delete()
        val mediaMuxer = MediaMuxer(temporaryFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
            val configUnits = nalUnits(codecConfig)
            val sps = configUnits.lastOrNull { nalType(it) == 7 }
                ?: throw IllegalStateException("La configuración H.264 no contiene SPS")
            val pps = configUnits.lastOrNull { nalType(it) == 8 }
                ?: throw IllegalStateException("La configuración H.264 no contiene PPS")
            // MediaCodec/MediaMuxer requiere los parameter sets AVC con el
            // start code Annex-B. scrcpy los entrega como configuración
            // separada; no deben escribirse después como frames del video.
            format.setByteBuffer("csd-0", ByteBuffer.wrap(withStartCode(sps)))
            format.setByteBuffer("csd-1", ByteBuffer.wrap(withStartCode(pps)))
            trackIndex = mediaMuxer.addTrack(format)
            mediaMuxer.start()
            muxer = mediaMuxer
            started = true
        } catch (error: Exception) {
            try { mediaMuxer.release() } catch (_: Exception) {}
            temporaryFile.delete()
            throw error
        }
    }

    @Synchronized
    fun writePacket(headerValue: Long, payload: ByteArray): Boolean {
        if (!started || (headerValue and FLAG_CONFIG) != 0L) return false
        val isKeyFrame = (headerValue and FLAG_KEY_FRAME) != 0L
        if (waitingForKeyFrame && !isKeyFrame) return false
        if (payload.isEmpty()) return false
        val firstSample = waitingForKeyFrame
        waitingForKeyFrame = false
        val pts = headerValue and PTS_MASK
        if (firstPtsUs < 0) firstPtsUs = pts
        val normalizedPtsUs = (pts - firstPtsUs).coerceAtLeast(0)
        if (lastPtsUs >= 0L) {
            val duration = normalizedPtsUs - lastPtsUs
            if (duration > 0L) lastSampleDurationUs = duration
        }
        bufferInfo.set(
            0,
            payload.size,
            normalizedPtsUs,
            if (isKeyFrame) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0,
        )
        // El payload proviene directamente del encoder usado por scrcpy. Se
        // conserva exactamente como salió de MediaCodec; convertir Annex-B a
        // AVCC aquí corrompe streams que el muxer espera en su forma original.
        muxer?.writeSampleData(trackIndex, ByteBuffer.wrap(payload), bufferInfo)
        lastPtsUs = normalizedPtsUs
        sampleCount++
        return firstSample
    }

    @Synchronized
    fun stop(): File {
        val activeMuxer = muxer
        var failure: Exception? = null
        try {
            check(started) { "El grabador no estaba iniciado" }
            val muxerToStop = checkNotNull(activeMuxer) { "MediaMuxer no estaba disponible" }
            check(sampleCount > 0) { "No se recibió un keyframe para crear el video" }
            // Un EOS vacío permite que MediaMuxer calcule la duración del
            // último frame. Es un marcador de contenedor, no un NAL H.264.
            bufferInfo.set(
                0,
                0,
                lastPtsUs + lastSampleDurationUs,
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
        if (failure == null && temporaryFile.isFile && temporaryFile.length() > 0L) {
            if (outputFile.exists()) outputFile.delete()
            if (!temporaryFile.renameTo(outputFile)) {
                failure = IllegalStateException("No se pudo instalar el MP4 final")
            }
        }
        if (failure == null) {
            try {
                validateFinalMp4(outputFile)
            } catch (error: Exception) {
                failure = error
            }
        }
        if (failure != null || !outputFile.isFile || outputFile.length() == 0L) {
            temporaryFile.delete()
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
        temporaryFile.delete()
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
        val nal = stripStartCode(unit)
        return if (nal.isNotEmpty()) nal[0].toInt() and 0x1F else -1
    }

    private fun nalUnits(data: ByteArray): List<ByteArray> {
        val annexBUnits = splitAnnexB(data)
        if (annexBUnits.isNotEmpty()) {
            return annexBUnits.map(::stripStartCode).filter { it.isNotEmpty() }
        }
        val avccUnits = splitAvcc(data)
        if (avccUnits.isNotEmpty()) return avccUnits
        return if (data.isNotEmpty()) listOf(data) else emptyList()
    }

    private fun splitAvcc(data: ByteArray): List<ByteArray> {
        if (data.size < 4) return emptyList()
        val units = mutableListOf<ByteArray>()
        var offset = 0
        while (offset + 4 <= data.size) {
            val length = ((data[offset].toInt() and 0xFF) shl 24) or
                ((data[offset + 1].toInt() and 0xFF) shl 16) or
                ((data[offset + 2].toInt() and 0xFF) shl 8) or
                (data[offset + 3].toInt() and 0xFF)
            offset += 4
            if (length <= 0 || offset + length > data.size) return emptyList()
            units += data.copyOfRange(offset, offset + length)
            offset += length
        }
        return if (offset == data.size && units.isNotEmpty()) units else emptyList()
    }

    private fun stripStartCode(unit: ByteArray): ByteArray {
        if (unit.size >= 4 && unit[0] == 0.toByte() && unit[1] == 0.toByte() &&
            unit[2] == 0.toByte() && unit[3] == 1.toByte()) {
            return unit.copyOfRange(4, unit.size)
        }
        if (unit.size >= 3 && unit[0] == 0.toByte() && unit[1] == 0.toByte() &&
            unit[2] == 1.toByte()) {
            return unit.copyOfRange(3, unit.size)
        }
        return unit
    }

    private fun withStartCode(unit: ByteArray): ByteArray {
        val nal = stripStartCode(unit)
        return byteArrayOf(0, 0, 0, 1) + nal
    }

    private fun validateFinalMp4(file: File) {
        check(file.isFile && file.length() > 0L) { "El MP4 final está vacío" }
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(file.absolutePath)
            check(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes") {
                "El MP4 final no contiene una pista de video válida"
            }
            val finalWidth = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull()
                ?: 0
            val finalHeight = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull()
                ?: 0
            check(finalWidth > 0 && finalHeight > 0) {
                "El MP4 final no contiene dimensiones de video válidas"
            }
        } finally {
            retriever.release()
        }
    }
}
