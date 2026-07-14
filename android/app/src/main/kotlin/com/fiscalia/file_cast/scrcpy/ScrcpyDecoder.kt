package com.fiscalia.file_cast.scrcpy

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.util.Log
import android.view.Surface

/**
 * Decodes H.264 video from scrcpy using MediaCodec in synchronous mode.
 *
 * scrcpy packet protocol (v2.7):
 * - sendFrameMeta=true: each frame is prefixed with 12 bytes:
 *   [0..7]  headerValue (Long BE): bits 63=FLAG_CONFIG, 62=FLAG_KEY_FRAME, 0-61=PTS
 *   [8..11] payload size (Int BE)
 * - payload: raw H.264 NALUs (may contain SPS/PPS config or frame data)
 *
 * Uses synchronous mode because async mode requires collecting input buffer
 * indices from onInputBufferAvailable — calling dequeueInputBuffer in async
 * mode throws IllegalStateException.
 */
class ScrcpyDecoder {

    companion object {
        private const val TAG = "ScrcpyDecoder"
        private const val FLAG_CONFIG = 1L shl 63
        private const val FLAG_KEY_FRAME = 1L shl 62
        private const val PTS_MASK = (1L shl 62) - 1
    }

    private var codec: MediaCodec? = null
    private var inputSurface: Surface? = null
    private var started = false
    private var configSent = false
    private var frameCount = 0
    private var configCount = 0
    // Reuse BufferInfo to avoid allocation per frame in drainOutputBuffers
    private val bufferInfo = MediaCodec.BufferInfo()

    fun start(width: Int, height: Int, surface: Surface) {
        Log.d(TAG, "start() ${width}x$height")

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }

        val mediaCodec = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        mediaCodec.configure(format, surface, null, 0)
        mediaCodec.start()

        this.codec = mediaCodec
        this.inputSurface = surface
        this.started = true
        this.configSent = false
        this.frameCount = 0
        this.configCount = 0

        Log.d(TAG, "Decoder started (synchronous mode)")
    }

    fun feedPacket(payload: ByteArray, headerValue: Long) {
        val mediaCodec = codec ?: return
        if (!started) return

        val isConfig = (headerValue and FLAG_CONFIG) != 0L

        if (isConfig) {
            handleConfigPacket(mediaCodec, payload)
            configCount++
            return
        }

        if (!configSent) return

        // Drain any available output buffers first (non-blocking)
        drainOutputBuffers(mediaCodec)

        // Feed the frame data
        try {
            val inputIndex = mediaCodec.dequeueInputBuffer(10_000)
            if (inputIndex >= 0) {
                val inputBuffer = mediaCodec.getInputBuffer(inputIndex) ?: return
                inputBuffer.clear()
                val size = minOf(payload.size, inputBuffer.capacity())
                inputBuffer.put(payload, 0, size)
                mediaCodec.queueInputBuffer(inputIndex, 0, size, headerValue and PTS_MASK, 0)
            }
        } catch (_: Exception) {}

        frameCount++
    }

    /**
     * Drain output buffers and render them to the surface.
     * Non-blocking — only processes buffers that are immediately available.
     * Reuses a single BufferInfo instance to avoid allocation per frame.
     */
    private fun drainOutputBuffers(mediaCodec: MediaCodec) {
        while (true) {
            bufferInfo.size = 0
            val outputIndex = mediaCodec.dequeueOutputBuffer(bufferInfo, 0)
            if (outputIndex >= 0) {
                mediaCodec.releaseOutputBuffer(outputIndex, true)
            } else {
                break
            }
        }
    }

    private fun handleConfigPacket(mediaCodec: MediaCodec, payload: ByteArray) {
        // Feed the config packet as codec-specific data
        try {
            val inputIndex = mediaCodec.dequeueInputBuffer(10_000)
            if (inputIndex >= 0) {
                val inputBuffer = mediaCodec.getInputBuffer(inputIndex) ?: return
                inputBuffer.clear()
                val size = minOf(payload.size, inputBuffer.capacity())
                inputBuffer.put(payload, 0, size)
                mediaCodec.queueInputBuffer(inputIndex, 0, size, 0, MediaCodec.BUFFER_FLAG_CODEC_CONFIG)
            }
        } catch (_: Exception) {}

        configSent = true
    }

    fun stop() {
        Log.d(TAG, "stop() - frames=$frameCount configs=$configCount")
        started = false
        configSent = false

        try {
            codec?.stop()
            codec?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping codec: ${e.message}")
        }
        codec = null
        inputSurface = null
    }

    fun isStarted(): Boolean = started
    fun getFrameCount(): Int = frameCount
    fun getConfigCount(): Int = configCount
}
