package com.fiscalia.file_cast.scrcpy

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Build
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
    private var outputWidth = 0
    private var outputHeight = 0
    private var lastStartError: String? = null
    private var onOutputSizeChanged: ((Int, Int) -> Unit)? = null
    // Reuse BufferInfo to avoid allocation per frame in drainOutputBuffers
    private val bufferInfo = MediaCodec.BufferInfo()

    fun start(
        width: Int,
        height: Int,
        surface: Surface,
        maxRetries: Int = 3,
        onOutputSizeChanged: ((Int, Int) -> Unit)? = null
    ): Boolean {
        Log.d(TAG, "start() ${width}x$height maxRetries=$maxRetries")
        this.outputWidth = width
        this.outputHeight = height
        this.onOutputSizeChanged = onOutputSizeChanged
        this.inputSurface = surface
        this.lastStartError = null

        var lastError: Exception? = null
        repeat(maxRetries) { attempt ->
            if (attempt > 0) {
                val delayMs = attempt * 500L
                Log.w(TAG, "Retry attempt $attempt/$maxRetries after ${delayMs}ms")
                Thread.sleep(delayMs)
            }
            var mediaCodec: MediaCodec? = null
            try {
                val format = MediaFormat.createVideoFormat(
                    MediaFormat.MIMETYPE_VIDEO_AVC,
                    width,
                    height,
                ).apply {
                    setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                    setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
                }
                // Ask Android for a decoder that supports this exact format.
                // createDecoderByType() may pick an OEM default that advertises
                // AVC but cannot allocate the requested portrait resolution.
                val codecName = MediaCodecList(MediaCodecList.REGULAR_CODECS)
                    .findDecoderForFormat(format)
                mediaCodec = if (codecName != null) {
                    MediaCodec.createByCodecName(codecName)
                } else {
                    // Some API 21 vendor tables under-report surface formats.
                    // Keep the legacy factory as a compatibility fallback;
                    // configure/start remains the authoritative probe.
                    MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
                }
                // Android 11+ may expose a dedicated real-time decoding path.
                // Probe the actual selected codec, not any AVC codec installed
                // on the device. If an OEM advertises it incorrectly and the
                // first configure fails, the next attempt intentionally falls
                // back to the standard format.
                if (attempt == 0 &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                    supportsLowLatencyDecoding(mediaCodec.codecInfo)
                ) {
                    format.setInteger(MediaFormat.KEY_LOW_LATENCY, 1)
                }
                mediaCodec.configure(format, surface, null, 0)
                mediaCodec.start()

                this.codec = mediaCodec
                this.started = true
                this.configSent = false
                this.frameCount = 0
                this.configCount = 0

                Log.d(
                    TAG,
                    "Decoder '${codecName ?: "default AVC"}' started " +
                        "(synchronous mode) on attempt ${attempt + 1}"
                )
                return true
            } catch (e: Exception) {
                lastError = e
                lastStartError = codecErrorDescription(e)
                Log.e(TAG, "Decoder start failed on attempt ${attempt + 1}: $lastStartError")
                // A failed configure/start moves many OEM codecs to a terminal
                // state. Always release the partial instance before retrying;
                // otherwise every retry consumes another scarce hardware slot.
                try {
                    mediaCodec?.stop()
                } catch (_: Exception) {
                    // The codec may not have reached the started state.
                }
                try {
                    mediaCodec?.release()
                } catch (_: Exception) {
                    // Best-effort cleanup for broken vendor codecs.
                }
            }
        }

        lastStartError = lastStartError ?: lastError?.message ?: "Unknown codec error"
        Log.e(TAG, "Decoder start failed after $maxRetries attempts: $lastStartError")
        try {
            inputSurface?.release()
        } catch (_: Exception) {
            // Surface release is best effort during a failed startup.
        }
        inputSurface = null
        return false
    }

    private fun supportsLowLatencyDecoding(codecInfo: MediaCodecInfo): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            codecInfo.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC)
                .isFeatureSupported(MediaCodecInfo.CodecCapabilities.FEATURE_LowLatency)
        } catch (_: Exception) {
            false
        }
    }

    private fun codecErrorDescription(error: Exception): String {
        if (error is MediaCodec.CodecException) {
            return buildString {
                append(error.diagnosticInfo)
                append(" (code=")
                append(error.errorCode)
                append(", transient=")
                append(error.isTransient)
                append(", recoverable=")
                append(error.isRecoverable)
                append(')')
            }
        }
        return error.message ?: error.javaClass.simpleName
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
            } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                updateOutputSize(mediaCodec.outputFormat)
            } else {
                break
            }
        }
    }

    private fun updateOutputSize(format: MediaFormat) {
        val width = visibleDimension(format, MediaFormat.KEY_WIDTH, "crop-left", "crop-right")
        val height = visibleDimension(format, MediaFormat.KEY_HEIGHT, "crop-top", "crop-bottom")
        if (width <= 0 || height <= 0 || (width == outputWidth && height == outputHeight)) return
        outputWidth = width
        outputHeight = height
        Log.d(TAG, "Output size changed: ${width}x$height")
        onOutputSizeChanged?.invoke(width, height)
    }

    private fun visibleDimension(
        format: MediaFormat,
        key: String,
        cropStartKey: String,
        cropEndKey: String
    ): Int {
        if (format.containsKey(cropStartKey) && format.containsKey(cropEndKey)) {
            return format.getInteger(cropEndKey) - format.getInteger(cropStartKey) + 1
        }
        return if (format.containsKey(key)) format.getInteger(key) else 0
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

        val codecToRelease = codec
        try {
            codecToRelease?.stop()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping codec: ${e.message}")
        }
        try {
            codecToRelease?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing codec: ${e.message}")
        }
        codec = null
        try {
            inputSurface?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing decoder surface: ${e.message}")
        }
        inputSurface = null
        onOutputSizeChanged = null
    }

    fun isStarted(): Boolean = started
    fun getFrameCount(): Int = frameCount
    fun getConfigCount(): Int = configCount
    fun getLastStartError(): String? = lastStartError
}
