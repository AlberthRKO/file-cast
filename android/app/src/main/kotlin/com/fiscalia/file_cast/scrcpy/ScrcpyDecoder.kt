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

    /**
     * Start the decoder with the given surface.
     * The surface should be backed by a SurfaceTexture from Flutter's TextureRegistry.
     */
    fun start(width: Int, height: Int, surface: Surface) {
        Log.d(TAG, "start() ${width}x$height")

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }

        // Synchronous mode — no callback, we poll input/output ourselves
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

    /**
     * Feed a raw scrcpy video packet to the decoder.
     *
     * @param payload The H.264 NALU data (without the 12-byte scrcpy frame header)
     * @param headerValue The 8-byte header value containing flags + PTS
     */
    fun feedPacket(payload: ByteArray, headerValue: Long) {
        val mediaCodec = codec ?: return
        if (!started) return

        val isConfig = (headerValue and FLAG_CONFIG) != 0L
        val isKeyFrame = (headerValue and FLAG_KEY_FRAME) != 0L
        val pts = headerValue and PTS_MASK

        if (isConfig) {
            handleConfigPacket(mediaCodec, payload)
            configCount++
            Log.d(TAG, "Fed CONFIG packet #$configCount (${payload.size} bytes)")
            return
        }

        if (!configSent) {
            Log.w(TAG, "Received frame before any config packet, skipping")
            return
        }

        // Drain any available output buffers first (non-blocking)
        drainOutputBuffers(mediaCodec)

        // Feed the frame data
        try {
            val inputIndex = mediaCodec.dequeueInputBuffer(10_000) // 10ms timeout
            if (inputIndex >= 0) {
                val inputBuffer = mediaCodec.getInputBuffer(inputIndex) ?: return
                inputBuffer.clear()
                val size = minOf(payload.size, inputBuffer.capacity())
                inputBuffer.put(payload, 0, size)
                mediaCodec.queueInputBuffer(inputIndex, 0, size, pts, 0)
            } else {
                Log.w(TAG, "No input buffer available, dropping frame")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error feeding frame: ${e.message}")
        }

        frameCount++
        if (frameCount % 50 == 0) {
            Log.d(TAG, "Fed FRAME packet #$frameCount (key=$isKeyFrame, pts=$pts, ${payload.size} bytes)")
        }
    }

    /**
     * Drain output buffers and render them to the surface.
     * Non-blocking — only processes buffers that are immediately available.
     */
    private fun drainOutputBuffers(mediaCodec: MediaCodec) {
        while (true) {
            val bufferInfo = MediaCodec.BufferInfo()
            val outputIndex = mediaCodec.dequeueOutputBuffer(bufferInfo, 0) // 0 = non-blocking
            if (outputIndex >= 0) {
                // Render to surface (true = render)
                mediaCodec.releaseOutputBuffer(outputIndex, true)
                if (frameCount % 100 == 0) {
                    Log.d(TAG, "Rendered frame #${frameCount} (size=${bufferInfo.size})")
                }
            } else {
                break // No more output buffers available right now
            }
        }
    }

    /**
     * Handle a config packet (SPS/PPS).
     * For H.264, the config contains SPS NALU followed by PPS NALU.
     * We feed it as codec-specific data so MediaCodec knows the stream parameters.
     */
    private fun handleConfigPacket(mediaCodec: MediaCodec, payload: ByteArray) {
        val nalus = splitNalus(payload)

        for (nalu in nalus) {
            if (nalu.size < 1) continue
            val naluType = nalu[0].toInt() and 0x1F
            when (naluType) {
                7 -> Log.d(TAG, "Config: SPS detected (${nalu.size} bytes)")
                8 -> Log.d(TAG, "Config: PPS detected (${nalu.size} bytes)")
                else -> Log.d(TAG, "Config: NALU type=$naluType (${nalu.size} bytes)")
            }
        }

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
        } catch (e: Exception) {
            Log.e(TAG, "Error feeding config packet: ${e.message}")
        }

        configSent = true
    }

    /**
     * Split a byte array into individual H.264 NALUs by finding start codes.
     * Supports both 3-byte (00 00 01) and 4-byte (00 00 00 01) start codes.
     */
    private fun splitNalus(data: ByteArray): List<ByteArray> {
        val nalus = mutableListOf<ByteArray>()
        var i = 0
        var naluStart = -1

        while (i < data.size - 2) {
            val isStartCode3 = data[i] == 0.toByte() && data[i + 1] == 0.toByte() && data[i + 2] == 1.toByte()
            val isStartCode4 = i < data.size - 3 && data[i] == 0.toByte() && data[i + 1] == 0.toByte() && data[i + 2] == 0.toByte() && data[i + 3] == 1.toByte()

            if (isStartCode4 || isStartCode3) {
                if (naluStart >= 0) {
                    nalus.add(data.copyOfRange(naluStart, i))
                }
                val startCodeLen = if (isStartCode4) 4 else 3
                naluStart = i + startCodeLen
                i += startCodeLen
            } else {
                i++
            }
        }

        // Last NALU
        if (naluStart >= 0 && naluStart < data.size) {
            nalus.add(data.copyOfRange(naluStart, data.size))
        }

        return nalus
    }

    /**
     * Stop and release the decoder.
     */
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
