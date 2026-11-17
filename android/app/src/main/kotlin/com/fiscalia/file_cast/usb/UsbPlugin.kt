package com.fiscalia.file_cast.usb

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import com.fiscalia.file_cast.adb.AdbAuth
import com.fiscalia.file_cast.scrcpy.ScrcpyDecoder
import com.fiscalia.file_cast.scrcpy.ScrcpyRecorder
import com.fiscalia.file_cast.sync.AdbSyncClient
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.CancellationException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.ConcurrentHashMap
import java.nio.ByteBuffer
import java.nio.ByteOrder

class UsbPlugin(private val context: Context, private val flutterEngine: FlutterEngine) {

    companion object {
        private const val TAG = "UsbPlugin"
        private const val METHOD_CHANNEL = "com.fiscalia.file_cast/usb"
        private const val EVENT_CHANNEL = "com.fiscalia.file_cast/usb/events"
        private const val ACTION_USB_PERMISSION = "com.fiscalia.file_cast.USB_PERMISSION"
        private const val FLAG_VIDEO_CONFIG = Long.MIN_VALUE
        private const val RECORDING_START_TIMEOUT_MS = 20_000L
        private const val MIN_FREE_SPACE_BYTES = 64L * 1024 * 1024
        private const val MAX_TRANSFER_BATCH_FILES = 200
        private const val MAX_PREVIEW_FILE_BYTES = 256L * 1024 * 1024
    }

    private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var pendingDevice: UsbDevice? = null

    // ADB components
    private val adbAuth = AdbAuth(context)
    private var adbTransport: UsbAdbTransport? = null
    private var currentConnection: android.hardware.usb.UsbDeviceConnection? = null
    private var resultCalled = false
    private var pendingHandshakeResult: MethodChannel.Result? = null
    private var pendingHandshakeDevice: UsbDevice? = null
    private var activeDeviceName: String? = null
    private var waitingForReattach = false
    private var handshakeGeneration = 0
    @Volatile private var lastAdbLog: String = ""
    @Volatile private var activeSyncClient: AdbSyncClient? = null
    private val fileTransferRunning = AtomicBoolean(false)
    private val adbDeviceMetadata = context.getSharedPreferences(
        "file_cast_adb_device_metadata",
        Context.MODE_PRIVATE,
    )

    // Mirror components
    private var mirrorTextureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var scrcpyDecoder: ScrcpyDecoder? = null
    private var controlStreamLocalId: Int? = null
    private var scrcpyServerShellLocalId: Int? = null
    @Volatile private var deviceScreenWidth: Int = 0
    @Volatile private var deviceScreenHeight: Int = 0
    @Volatile private var mirrorVideoWidth: Int = 0
    @Volatile private var mirrorVideoHeight: Int = 0
    private var scrcpyHeaderWidth: Int = 0
    private var scrcpyHeaderHeight: Int = 0
    private var wmSizeWidth: Int = 0
    private var wmSizeHeight: Int = 0
    private var wmSizeRaw: String = ""
    private var lastTouchInfo: String = "none"
    @Volatile private var recorder: ScrcpyRecorder? = null
    private var lastCodecConfig: ByteArray? = null
    private val recorderLock = Any()
    private var pendingRecordingStartResult: MethodChannel.Result? = null
    private var recordingStartTimeout: Runnable? = null

    /**
     * Multi-mirror sessions are deliberately isolated from the legacy single
     * mirror fields above.  The existing routes keep using the legacy session;
     * the map lets a hub host N independent ADB/scrcpy transports without
     * sharing a connection, decoder, texture or recorder.
     */
    private val multiSessions = ConcurrentHashMap<String, MultiMirrorState>()

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)

                    if (granted && device != null) {
                        sendDeviceConnected(device)
                    } else {
                        sendEvent("permission_denied", mapOf(
                            "deviceName" to (device?.deviceName ?: "unknown")
                        ))
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                    if (device != null) {
                        Log.d(TAG, "USB DEVICE ATTACHED: ${device.deviceName} VID=0x${Integer.toHexString(device.vendorId)} PID=0x${Integer.toHexString(device.productId)}")
                        sendEvent("device_attached", deviceToMap(device))

                        // If we were waiting for re-attach after ADB auth, auto-retry
                        if (waitingForReattach && pendingHandshakeResult != null) {
                            Log.d(TAG, "Got re-attach after ADB auth, auto-retrying connection...")
                            waitingForReattach = false
                            val savedResult = pendingHandshakeResult
                            pendingHandshakeResult = null
                            mainHandler.post {
                                handshakeGeneration += 1
                                connectAdbInternal(device, savedResult!!, handshakeGeneration)
                            }
                        }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                    if (device != null) {
                        Log.d(TAG, "USB DEVICE DETACHED: ${device.deviceName}")

                        // If we're in the middle of handshake, set flag for re-attach
                        if (adbTransport != null && !resultCalled) {
                            Log.d(TAG, "Device detached during handshake, waiting for re-attach...")
                            waitingForReattach = true
                        }

                        val multi = multiSessions.values.firstOrNull {
                            it.device.deviceName == device.deviceName
                        }
                        if (multi != null) {
                            disconnectMultiSession(multi.sourceSessionId, notify = true)
                        } else if (pendingHandshakeDevice?.deviceName == device.deviceName ||
                            activeDeviceName == device.deviceName) {
                            disconnectAdb()
                        }
                        sendEvent("device_detached", deviceToMap(device))
                    }
                }
            }
        }
    }

    fun register() {
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(usbReceiver, filter)
        }

        setupMethodChannel()
        setupEventChannel()
    }

    fun unregister() {
        disconnectAdb()
        multiSessions.keys.toList().forEach { disconnectMultiSession(it, notify = false) }
        try {
            context.unregisterReceiver(usbReceiver)
        } catch (_: Exception) {}
    }

    private fun setupMethodChannel() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isOtgSupported" -> result.success(isOtgSupported())
                "getConnectedDevices" -> result.success(getConnectedDevices())
                "requestPermission" -> {
                    val deviceName = call.argument<String>("deviceName")
                    requestPermission(deviceName, result)
                }
                "hasPermission" -> {
                    val deviceName = call.argument<String>("deviceName")
                    result.success(hasPermission(deviceName))
                }
                "openDevice" -> {
                    val deviceName = call.argument<String>("deviceName")
                    openDevice(deviceName, result)
                }
                "connectAdb" -> {
                    val deviceName = call.argument<String>("deviceName")
                    connectAdb(deviceName, result)
                }
                "disconnectAdb" -> {
                    disconnectAdb()
                    result.success(true)
                }
                "multiConnectAdb" -> {
                    val sourceSessionId = call.argument<String>("sourceSessionId")
                    val deviceName = call.argument<String>("deviceName")
                    if (sourceSessionId == null || deviceName == null) {
                        result.error("INVALID_ARGS", "sourceSessionId and deviceName are required", null)
                    } else {
                        connectMultiAdb(sourceSessionId, deviceName, result)
                    }
                }
                "multiPushFile" -> {
                    val sourceSessionId = call.argument<String>("sourceSessionId")
                    val localPath = call.argument<String>("localPath")
                    val remotePath = call.argument<String>("remotePath")
                    if (sourceSessionId == null || localPath == null || remotePath == null) {
                        result.error("INVALID_ARGS", "sourceSessionId, localPath and remotePath are required", null)
                    } else {
                        multiPushFile(sourceSessionId, localPath, remotePath, result)
                    }
                }
                "multiStartPersistentShell" -> {
                    val sourceSessionId = call.argument<String>("sourceSessionId")
                    val command = call.argument<String>("command")
                    if (sourceSessionId == null || command == null) {
                        result.error("INVALID_ARGS", "sourceSessionId and command are required", null)
                    } else {
                        multiStartPersistentShell(sourceSessionId, command, result)
                    }
                }
                "multiShellCommand" -> {
                    val sourceSessionId = call.argument<String>("sourceSessionId")
                    val command = call.argument<String>("command")
                    if (sourceSessionId == null || command == null) {
                        result.error("INVALID_ARGS", "sourceSessionId and command are required", null)
                    } else {
                        multiShellCommand(sourceSessionId, command, result)
                    }
                }
                "multiConnectScrcpySockets" -> {
                    val sourceSessionId = call.argument<String>("sourceSessionId")
                    if (sourceSessionId == null) {
                        result.error("INVALID_ARGS", "sourceSessionId is required", null)
                    } else {
                        multiConnectScrcpySockets(sourceSessionId, result)
                    }
                }
                "multiCreateMirrorTexture" -> {
                    val sourceSessionId = call.argument<String>("sourceSessionId")
                    if (sourceSessionId == null) {
                        result.error("INVALID_ARGS", "sourceSessionId is required", null)
                    } else {
                        multiCreateMirrorTexture(sourceSessionId, result)
                    }
                }
                "multiStartMirror" -> {
                    val sourceSessionId = call.argument<String>("sourceSessionId")
                    val width = call.argument<Number>("width")?.toInt()
                    val height = call.argument<Number>("height")?.toInt()
                    val localId = call.argument<Number>("videoStreamLocalId")?.toInt()
                    if (sourceSessionId == null || width == null || height == null || localId == null) {
                        result.error("INVALID_ARGS", "sourceSessionId, width, height and videoStreamLocalId are required", null)
                    } else {
                        multiStartMirror(sourceSessionId, width, height, localId, result)
                    }
                }
                "multiStopMirror" -> {
                    val sourceSessionId = call.argument<String>("sourceSessionId")
                    if (sourceSessionId == null) {
                        result.error("INVALID_ARGS", "sourceSessionId is required", null)
                    } else {
                        stopMultiMirror(sourceSessionId)
                        result.success(mapOf("stopped" to true))
                    }
                }
                "multiDisconnectAdb" -> {
                    val sourceSessionId = call.argument<String>("sourceSessionId")
                    if (sourceSessionId == null) {
                        result.error("INVALID_ARGS", "sourceSessionId is required", null)
                    } else {
                        disconnectMultiSession(sourceSessionId, notify = false)
                        result.success(true)
                    }
                }
                "multiSendTouch" -> multiSendTouch(call, result)
                "multiSendKey" -> multiSendKey(call, result)
                "multiSendScroll" -> multiSendScroll(call, result)
                "multiCaptureScreenshot" -> multiCaptureScreenshot(call, result)
                "multiStartScreenRecording" -> multiStartScreenRecording(call, result)
                "multiStopScreenRecording" -> multiStopScreenRecording(call, result)
                "multiGetMirrorLog" -> multiGetMirrorLog(call, result)
                "getMultiSessions" -> result.success(multiSessions.values.map { it.toMap() })
                "getAdbState" -> {
                    result.success(mapOf(
                        "connected" to (adbTransport?.isAdbConnected() ?: false)
                    ))
                }
                "getAdbLog" -> {
                    val activeLog = adbTransport?.getLog().orEmpty()
                    result.success(mapOf(
                        "log" to (activeLog.ifBlank { lastAdbLog })
                    ))
                }
                "shellCommand" -> {
                    val command = call.argument<String>("command")
                    val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 15000L
                    if (command == null) {
                        result.error("INVALID_ARGS", "command is required", null)
                        return@setMethodCallHandler
                    }
                    val transport = adbTransport
                    if (transport == null || !transport.isAdbConnected()) {
                        result.error("NOT_CONNECTED", "ADB not connected", null)
                        return@setMethodCallHandler
                    }
                    // Run shell command on background thread
                    Thread {
                        try {
                            val output = transport.shellCommand(command, timeoutMs)
                            mainHandler.post {
                                result.success(mapOf(
                                    "output" to output,
                                    "success" to true
                                ))
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "shellCommand error: ${e.message}")
                            mainHandler.post {
                                result.error("SHELL_ERROR", e.message ?: "Shell command failed", null)
                            }
                        }
                    }.apply {
                        name = "ShellCmd"
                        isDaemon = true
                        start()
                    }
                }
                "pushFile" -> {
                    val localPath = call.argument<String>("localPath")
                    val remotePath = call.argument<String>("remotePath")
                    val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 30000L
                    if (localPath == null || remotePath == null) {
                        result.error("INVALID_ARGS", "localPath and remotePath are required", null)
                        return@setMethodCallHandler
                    }
                    val transport = adbTransport
                    if (transport == null || !transport.isAdbConnected()) {
                        result.error("NOT_CONNECTED", "ADB not connected", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val success = transport.pushFile(localPath, remotePath, timeoutMs)
                            mainHandler.post {
                                result.success(mapOf(
                                    "success" to success,
                                    "remotePath" to remotePath
                                ))
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "pushFile error: ${e.message}")
                            mainHandler.post {
                                result.error("PUSH_ERROR", e.message ?: "Push failed", null)
                            }
                        }
                    }.apply {
                        name = "PushFile"
                        isDaemon = true
                        start()
                    }
                }
                "listRemoteFiles" -> {
                    val remotePath = call.argument<String>("remotePath")
                    val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 30000L
                    if (remotePath == null) {
                        result.error("INVALID_ARGS", "remotePath is required", null)
                        return@setMethodCallHandler
                    }
                    val transport = adbTransport
                    if (transport == null || !transport.isAdbConnected()) {
                        result.error("NOT_CONNECTED", "ADB not connected", null)
                        return@setMethodCallHandler
                    }
                    if (fileTransferRunning.get()) {
                        result.error("TRANSFER_BUSY", "A file transfer is already running", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val syncClient = AdbSyncClient(transport)
                        syncClient.resetCancellation()
                        activeSyncClient = syncClient
                        try {
                            val entries = syncClient.listDirectory(remotePath, timeoutMs)
                            mainHandler.post { result.success(entries.map { it.toMap() }) }
                        } catch (e: Exception) {
                            Log.e(TAG, "listRemoteFiles error: ${e.message}", e)
                            mainHandler.post {
                                result.error("REMOTE_LIST_ERROR", e.message ?: "Could not list remote files", null)
                            }
                        } finally {
                            if (activeSyncClient === syncClient) activeSyncClient = null
                        }
                    }.apply {
                        name = "ListRemoteFiles"
                        isDaemon = true
                        start()
                    }
                }
                "statRemoteFile" -> {
                    val remotePath = call.argument<String>("remotePath")
                    val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 30000L
                    if (remotePath == null) {
                        result.error("INVALID_ARGS", "remotePath is required", null)
                        return@setMethodCallHandler
                    }
                    val transport = adbTransport
                    if (transport == null || !transport.isAdbConnected()) {
                        result.error("NOT_CONNECTED", "ADB not connected", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val syncClient = AdbSyncClient(transport)
                        syncClient.resetCancellation()
                        activeSyncClient = syncClient
                        try {
                            val entry = syncClient.stat(remotePath, timeoutMs)
                            mainHandler.post { result.success(entry.toMap()) }
                        } catch (e: Exception) {
                            Log.e(TAG, "statRemoteFile error: ${e.message}", e)
                            mainHandler.post {
                                result.error("REMOTE_STAT_ERROR", e.message ?: "Could not read remote metadata", null)
                            }
                        } finally {
                            if (activeSyncClient === syncClient) activeSyncClient = null
                        }
                    }.apply {
                        name = "StatRemoteFile"
                        isDaemon = true
                        start()
                    }
                }
                "pullRemoteFiles" -> {
                    val requisitionId = call.argument<String>("requisitionId")
                    val sessionId = call.argument<String>("sessionId")
                    val transferId = call.argument<String>("transferId")
                    val remotePaths = call.argument<List<String>>("remotePaths")
                    val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 30000L
                    val previewOnly = call.argument<Boolean>("previewOnly") ?: false
                    if (requisitionId == null || sessionId == null || transferId == null || remotePaths.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "requisitionId, sessionId, transferId and remotePaths are required", null)
                        return@setMethodCallHandler
                    }
                    if (remotePaths.size > MAX_TRANSFER_BATCH_FILES) {
                        result.error("BATCH_TOO_LARGE", "A transfer batch supports up to 200 files", null)
                        return@setMethodCallHandler
                    }
                    if (previewOnly && remotePaths.size != 1) {
                        result.error("INVALID_ARGS", "A preview requires exactly one file", null)
                        return@setMethodCallHandler
                    }
                    val transport = adbTransport
                    if (transport == null || !transport.isAdbConnected()) {
                        result.error("NOT_CONNECTED", "ADB not connected", null)
                        return@setMethodCallHandler
                    }
                    if (!fileTransferRunning.compareAndSet(false, true)) {
                        result.error("TRANSFER_BUSY", "A file transfer is already running", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val syncClient = AdbSyncClient(transport)
                        syncClient.resetCancellation()
                        activeSyncClient = syncClient
                        val completed = mutableListOf<Map<String, Any>>()
                        val failures = mutableListOf<Map<String, String>>()
                        var wasCancelled = false
                        try {
                            val remoteEntries = remotePaths.map { syncClient.stat(it, timeoutMs) }
                            val totalBytes = remoteEntries.fold(0L) { total, entry -> total + entry.byteLength }
                            if (previewOnly && totalBytes > MAX_PREVIEW_FILE_BYTES) {
                                throw IllegalStateException("El archivo supera el límite de 256 MB para vista previa")
                            }
                            val destination = if (previewOnly) {
                                previewDirectory(requisitionId, sessionId).apply {
                                    deleteRecursively()
                                    mkdirs()
                                }
                            } else {
                                evidenceDirectory(requisitionId, sessionId)
                            }
                            if (destination.usableSpace - MIN_FREE_SPACE_BYTES < totalBytes) {
                                throw IllegalStateException("No hay espacio suficiente para transferir el lote seleccionado")
                            }
                            var batchBytes = 0L
                            remoteEntries.forEachIndexed { index, remote ->
                                if (wasCancelled) return@forEachIndexed
                                val baseBatchBytes = batchBytes
                                postTransferEvent(mapOf(
                                    "transferId" to transferId,
                                    "state" to "transferring",
                                    "fileName" to remote.name,
                                    "fileIndex" to index,
                                    "fileCount" to remoteEntries.size,
                                    "fileBytes" to 0L,
                                    "fileTotalBytes" to remote.byteLength,
                                    "batchBytes" to batchBytes,
                                    "batchTotalBytes" to totalBytes,
                                ))
                                try {
                                    val pulled = syncClient.pullFile(
                                        remotePath = remote.path,
                                        destinationDirectory = destination,
                                        knownRemote = remote,
                                        timeoutMs = timeoutMs,
                                    ) { fileBytes ->
                                        postTransferEvent(mapOf(
                                            "transferId" to transferId,
                                            "state" to "transferring",
                                            "fileName" to remote.name,
                                            "fileIndex" to index,
                                            "fileCount" to remoteEntries.size,
                                            "fileBytes" to fileBytes,
                                            "fileTotalBytes" to remote.byteLength,
                                            "batchBytes" to baseBatchBytes + fileBytes,
                                            "batchTotalBytes" to totalBytes,
                                        ))
                                    }
                                    completed += pulled.toMap()
                                    batchBytes += pulled.byteLength
                                } catch (_: CancellationException) {
                                    wasCancelled = true
                                } catch (e: Exception) {
                                    failures += mapOf("path" to remote.path, "message" to (e.message ?: "Transfer failed"))
                                }
                            }
                            postTransferEvent(mapOf(
                                "transferId" to transferId,
                                "state" to if (wasCancelled) "cancelled" else "completed",
                                "fileCount" to remoteEntries.size,
                                "completedCount" to completed.size,
                                "failureCount" to failures.size,
                                "batchBytes" to batchBytes,
                                "batchTotalBytes" to totalBytes,
                            ))
                            mainHandler.post {
                                result.success(mapOf(
                                    "files" to completed,
                                    "failures" to failures,
                                    "cancelled" to wasCancelled,
                                ))
                            }
                        } catch (_: CancellationException) {
                            wasCancelled = true
                            postTransferEvent(mapOf("transferId" to transferId, "state" to "cancelled"))
                            mainHandler.post {
                                result.success(mapOf("files" to completed, "failures" to failures, "cancelled" to true))
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "pullRemoteFiles error: ${e.message}", e)
                            postTransferEvent(mapOf(
                                "transferId" to transferId,
                                "state" to "error",
                                "message" to (e.message ?: "File transfer failed"),
                            ))
                            mainHandler.post {
                                result.error("REMOTE_PULL_ERROR", e.message ?: "File transfer failed", null)
                            }
                        } finally {
                            if (activeSyncClient === syncClient) activeSyncClient = null
                            fileTransferRunning.set(false)
                        }
                    }.apply {
                        name = if (previewOnly) "PreviewRemoteFile" else "PullRemoteFiles"
                        isDaemon = true
                        start()
                    }
                }
                "discardRemoteFilePreview" -> {
                    val requisitionId = call.argument<String>("requisitionId")
                    val sessionId = call.argument<String>("sessionId")
                    if (requisitionId == null || sessionId == null) {
                        result.error("INVALID_ARGS", "requisitionId and sessionId are required", null)
                        return@setMethodCallHandler
                    }
                    previewDirectory(requisitionId, sessionId).deleteRecursively()
                    result.success(null)
                }
                "cancelFileTransfer" -> {
                    activeSyncClient?.cancel()
                    result.success(true)
                }
                "startPersistentShell" -> {
                    val command = call.argument<String>("command")
                    val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 10000L
                    if (command == null) {
                        result.error("INVALID_ARGS", "command is required", null)
                        return@setMethodCallHandler
                    }
                    val transport = adbTransport
                    if (transport == null || !transport.isAdbConnected()) {
                        result.error("NOT_CONNECTED", "ADB not connected", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val localId = transport.startPersistentShell(command, timeoutMs)
                            if (command.contains("scrcpy.Server") || command.contains("scrcpy-server")) {
                                scrcpyServerShellLocalId = localId
                                Log.d(TAG, "Saved scrcpy server shell localId=$localId")
                            }
                            mainHandler.post {
                                result.success(mapOf(
                                    "localId" to localId,
                                    "success" to true
                                ))
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "startPersistentShell error: ${e.message}")
                            mainHandler.post {
                                result.error("SHELL_ERROR", e.message ?: "Failed to start shell", null)
                            }
                        }
                    }.apply {
                        name = "StartPersistentShell"
                        isDaemon = true
                        start()
                    }
                }
                "openStream" -> {
                    val service = call.argument<String>("service")
                    val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 10000L
                    if (service == null) {
                        result.error("INVALID_ARGS", "service is required", null)
                        return@setMethodCallHandler
                    }
                    val transport = adbTransport
                    if (transport == null || !transport.isAdbConnected()) {
                        result.error("NOT_CONNECTED", "ADB not connected", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val stream = transport.openStream(service, timeoutMs)
                            mainHandler.post {
                                result.success(mapOf(
                                    "localId" to stream.localId,
                                    "remoteId" to stream.remoteId
                                ))
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "openStream error: ${e.message}")
                            mainHandler.post {
                                result.error("STREAM_ERROR", e.message ?: "Failed to open stream", null)
                            }
                        }
                    }.apply {
                        name = "OpenStream"
                        isDaemon = true
                        start()
                    }
                }
                "readStream" -> {
                    val localId = call.argument<Number>("localId")?.toInt()
                    val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 10000L
                    if (localId == null) {
                        result.error("INVALID_ARGS", "localId is required", null)
                        return@setMethodCallHandler
                    }
                    val transport = adbTransport
                    if (transport == null || !transport.isAdbConnected()) {
                        result.error("NOT_CONNECTED", "ADB not connected", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val stream = transport.getStream(localId)
                            if (stream == null) {
                                mainHandler.post {
                                    result.error("STREAM_ERROR", "No stream with localId=$localId", null)
                                }
                                return@Thread
                            }
                            val data = stream.dataQueue.poll(timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
                            if (data == null) {
                                mainHandler.post {
                                    result.success(mapOf(
                                        "data" to null,
                                        "closed" to stream.closed.get()
                                    ))
                                }
                            } else {
                                mainHandler.post {
                                    result.success(mapOf(
                                        "data" to data,
                                        "closed" to stream.closed.get()
                                    ))
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "readStream error: ${e.message}")
                            mainHandler.post {
                                result.error("STREAM_ERROR", e.message ?: "Failed to read stream", null)
                            }
                        }
                    }.apply {
                        name = "ReadStream"
                        isDaemon = true
                        start()
                    }
                }
                "closeStream" -> {
                    val localId = call.argument<Number>("localId")?.toInt()
                    if (localId == null) {
                        result.error("INVALID_ARGS", "localId is required", null)
                        return@setMethodCallHandler
                    }
                    val transport = adbTransport
                    if (transport != null) {
                        transport.closeStream(localId)
                    }
                    result.success(true)
                }
                "getTransportLog" -> {
                    result.success(mapOf(
                        "log" to (adbTransport?.getLog() ?: "")
                    ))
                }
                "createMirrorTexture" -> {
                    try {
                        if (mirrorTextureEntry != null || scrcpyDecoder != null) {
                            result.error("MIRROR_ALREADY_ACTIVE", "Ya existe una sesión de espejo activa", null)
                            return@setMethodCallHandler
                        }
                        val entry = flutterEngine.renderer.createSurfaceTexture()
                        mirrorTextureEntry = entry
                        val textureId = entry.id()
                        Log.d(TAG, "Mirror texture created: id=$textureId")
                        result.success(mapOf("textureId" to textureId))
                    } catch (e: Exception) {
                        Log.e(TAG, "createMirrorTexture error: ${e.message}")
                        result.error("TEXTURE_ERROR", e.message ?: "Failed to create texture", null)
                    }
                }
                "startMirror" -> {
                    val width = call.argument<Number>("width")?.toInt()
                    val height = call.argument<Number>("height")?.toInt()
                    val localId = call.argument<Number>("videoStreamLocalId")?.toInt()
                    if (width == null || height == null || localId == null) {
                        result.error("INVALID_ARGS", "width, height, videoStreamLocalId required", null)
                        return@setMethodCallHandler
                    }
                    val entry = mirrorTextureEntry
                    val transport = adbTransport
                    if (entry == null || transport == null) {
                        result.error("NOT_READY", "Texture o transporte no inicializado", null)
                        return@setMethodCallHandler
                    }
                    if (scrcpyDecoder != null) {
                        result.error("MIRROR_ALREADY_ACTIVE", "El decoder de espejo ya está activo", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val surfaceTexture = entry.surfaceTexture()
                            mirrorVideoWidth = width
                            mirrorVideoHeight = height
                            surfaceTexture.setDefaultBufferSize(width, height)
                            if (!transport.enableVideoFlowControl(localId)) {
                                throw IllegalStateException("El stream de video $localId ya no está disponible")
                            }
                            val surface = Surface(surfaceTexture)

                            val decoder = ScrcpyDecoder()
                            scrcpyDecoder = decoder
                            val started = decoder.start(
                                width = width,
                                height = height,
                                surface = surface,
                                onOutputSizeChanged = { outputWidth, outputHeight ->
                                    mirrorVideoWidth = outputWidth
                                    mirrorVideoHeight = outputHeight
                                    deviceScreenWidth = outputWidth
                                    deviceScreenHeight = outputHeight
                                    mainHandler.post {
                                        surfaceTexture.setDefaultBufferSize(outputWidth, outputHeight)
                                        sendEvent("mirror_state", mapOf(
                                            "state" to "video_size",
                                            "width" to outputWidth,
                                            "height" to outputHeight
                                        ))
                                    }
                                }
                            )
                            if (!started) {
                                val codecError = decoder.getLastStartError()
                                    ?: "El decodificador H.264 del inspector no aceptó ${width}x$height"
                                Log.e(TAG, "Decoder failed to start after retries: $codecError")
                                decoder.stop()
                                scrcpyDecoder = null
                                mainHandler.post {
                                    result.error("CODEC_ERROR", codecError, mapOf(
                                        "width" to width,
                                        "height" to height,
                                        "retryableAtLowerResolution" to true,
                                    ))
                                }
                                return@Thread
                            }

                            // Suppress verbose logging during active mirror for performance
                            transport.quietMode = true

                            transport.startVideoReadLoop(
                                localId = localId,
                                onPacket = { headerValue, payload ->
                                    decoder.feedPacket(payload, headerValue)
                                    val recordingStarted = synchronized(recorderLock) {
                                        if ((headerValue and FLAG_VIDEO_CONFIG) != 0L) {
                                            lastCodecConfig = (lastCodecConfig ?: byteArrayOf()) + payload
                                            false
                                        } else {
                                            recorder?.writePacket(headerValue, payload) == true
                                        }
                                    }
                                    if (recordingStarted) {
                                        mainHandler.post { completeRecordingStart() }
                                    }
                                },
                                onError = { msg ->
                                    Log.e(TAG, "Video error: $msg")
                                    mainHandler.post {
                                        sendEvent("mirror_state", mapOf(
                                            "state" to "error",
                                            "message" to msg
                                        ))
                                    }
                                }
                            )

                            mainHandler.post {
                                result.success(mapOf("started" to true))
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "startMirror error: ${e.message}", e)
                            scrcpyDecoder?.stop()
                            scrcpyDecoder = null
                            mainHandler.post {
                                result.error("MIRROR_ERROR", e.message ?: "Failed to start mirror", null)
                            }
                        }
                    }.apply {
                        name = "StartMirror"
                        isDaemon = true
                        start()
                    }
                }
                "stopMirror" -> {
                    adbTransport?.quietMode = false
                    adbTransport?.stopVideoReadLoop()
                    adbTransport?.stopControlWriter()
                    scrcpyDecoder?.stop()
                    scrcpyDecoder = null
                    stopRecorderSafely()
                    synchronized(recorderLock) {
                        lastCodecConfig = null
                    }
                    scrcpyServerShellLocalId = null
                    wmSizeWidth = 0
                    wmSizeHeight = 0
                    wmSizeRaw = ""
                    scrcpyHeaderWidth = 0
                    scrcpyHeaderHeight = 0
                    mirrorVideoWidth = 0
                    mirrorVideoHeight = 0
                    mirrorTextureEntry?.release()
                    mirrorTextureEntry = null
                    Log.d(TAG, "Mirror stopped")
                    result.success(mapOf("stopped" to true))
                }
                "captureScreenshot" -> captureScreenshot(call, result)
                "startScreenRecording" -> startScreenRecording(call, result)
                "stopScreenRecording" -> stopScreenRecording(result)
                "getMirrorLog" -> {
                    val decoder = scrcpyDecoder
                    val transport = adbTransport
                    val controlId = controlStreamLocalId
                    val log = StringBuilder()
                    if (decoder != null) {
                        log.appendLine("Decoder: started=${decoder.isStarted()} frames=${decoder.getFrameCount()} configs=${decoder.getConfigCount()}")
                    } else {
                        log.appendLine("Decoder: not initialized")
                    }
                    if (controlId != null && transport != null) {
                        val open = transport.isStreamOpen(controlId)
                        log.appendLine("Control stream: localId=$controlId open=$open")
                        log.appendLine("Control writes: ${transport.getControlWriteStats()}")
                    } else {
                        log.appendLine("Control stream: not set")
                    }
                    log.appendLine("Header size: ${scrcpyHeaderWidth}x${scrcpyHeaderHeight}")
                    log.appendLine("MediaCodec size: ${mirrorVideoWidth}x${mirrorVideoHeight}")
                    log.appendLine("Touch packet size: ${deviceScreenWidth}x${deviceScreenHeight}")
                    synchronized(recorderLock) {
                        log.appendLine(
                            "Recording: active=${recorder != null} " +
                                "waitingForKeyframe=${pendingRecordingStartResult != null} " +
                                "codecConfigBytes=${lastCodecConfig?.size ?: 0}"
                        )
                    }
                    if (wmSizeWidth > 0) {
                        log.appendLine("wm size: ${wmSizeWidth}x${wmSizeHeight}")
                        if (wmSizeWidth != scrcpyHeaderWidth || wmSizeHeight != scrcpyHeaderHeight) {
                            log.appendLine("NOTE: header and wm size differ (this may be expected).")
                        }
                    } else if (wmSizeRaw.isNotEmpty()) {
                        log.appendLine("wm size: $wmSizeRaw")
                    }
                    log.appendLine("Last touch: $lastTouchInfo")
                    result.success(mapOf(
                        "log" to log.toString(),
                        "videoWidth" to mirrorVideoWidth,
                        "videoHeight" to mirrorVideoHeight,
                        "touchWidth" to deviceScreenWidth,
                        "touchHeight" to deviceScreenHeight,
                        "wmWidth" to wmSizeWidth,
                        "wmHeight" to wmSizeHeight
                    ))
                }
                "getServerLog" -> {
                    val localId = scrcpyServerShellLocalId
                    val transport = adbTransport
                    if (localId == null || transport == null) {
                        result.success(mapOf("log" to "(server shell not started)"))
                        return@setMethodCallHandler
                    }
                    val stream = transport.getStream(localId)
                    if (stream == null) {
                        result.success(mapOf("log" to "(stream closed)"))
                        return@setMethodCallHandler
                    }
                    val sb = StringBuilder()
                    var chunk = stream.dataQueue.poll()
                    while (chunk != null) {
                        sb.append(String(chunk, Charsets.UTF_8))
                        chunk = stream.dataQueue.poll()
                    }
                    result.success(mapOf("log" to sb.toString()))
                }
                "getDeviceScreenSize" -> {
                    val transport = adbTransport
                    if (transport == null || !transport.isAdbConnected()) {
                        result.error("NOT_CONNECTED", "ADB not connected", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val output = transport.shellCommand("wm size")
                            val matches = Regex("(?:Physical|Override) size: (\\d+)x(\\d+)")
                                .findAll(output)
                                .toList()
                            val match = matches.lastOrNull()
                            if (match != null) {
                                val w = match.groupValues[1].toInt()
                                val h = match.groupValues[2].toInt()
                                Log.d(TAG, "Device effective screen size: ${w}x${h}")
                                mainHandler.post {
                                    result.success(mapOf("width" to w, "height" to h))
                                }
                            } else {
                                Log.e(TAG, "Could not parse wm size output: $output")
                                mainHandler.post {
                                    result.error("PARSE_ERROR", "Could not parse screen size: $output", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "getDeviceScreenSize error: ${e.message}")
                            mainHandler.post {
                                result.error("SCREEN_SIZE_ERROR", e.message, null)
                            }
                        }
                    }.apply { name = "GetDeviceScreenSize"; isDaemon = true; start() }
                }
                "sendTouch" -> {
                    val controlId = controlStreamLocalId
                    val transport = adbTransport
                    if (controlId == null || transport == null) {
                        Log.e(TAG, "sendTouch rejected: controlId=$controlId transport=${transport != null}")
                        result.error("NOT_READY", "Control stream not initialized", null)
                        return@setMethodCallHandler
                    }
                    if (!transport.isStreamOpen(controlId)) {
                        Log.e(TAG, "sendTouch rejected: control stream $controlId is closed")
                        result.error("STREAM_CLOSED", "Control stream $controlId is closed", null)
                        return@setMethodCallHandler
                    }
                    val action = call.argument<Number>("action")?.toInt() ?: 0
                    val pointerId = call.argument<Number>("pointerId")?.toLong() ?: 1L
                    val x = call.argument<Number>("x")?.toInt() ?: 0
                    val y = call.argument<Number>("y")?.toInt() ?: 0
                    // Use the current decoded video dimensions. They begin with
                    // the scrcpy header and are updated after target rotation.
                    val screenWidth = deviceScreenWidth
                    val screenHeight = deviceScreenHeight
                    if (screenWidth <= 0 || screenHeight <= 0) {
                        result.error("INVALID_VIDEO_SIZE", "scrcpy video size is not available", null)
                        return@setMethodCallHandler
                    }
                    val pressure = if (action == 1) 0 else 0xFFFF
                    if (action != 2) {
                        Log.d(TAG, "sendTouch: action=$action pointer=$pointerId x=$x y=$y screen=${screenWidth}x${screenHeight}")
                    }
                    lastTouchInfo = "action=$action pointer=$pointerId x=$x y=$y screen=${screenWidth}x${screenHeight}"
                    try {
                        val packet = com.fiscalia.file_cast.scrcpy.ScrcpyControl.buildTouchPacket(
                            action, pointerId, x, y, screenWidth, screenHeight, pressure
                        )
                        transport.enqueueControlWrite(controlId, packet)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "sendTouch error: ${e.message}", e)
                        result.error("TOUCH_ERROR", e.message, null)
                    }
                }
                "sendKey" -> {
                    val controlId = controlStreamLocalId
                    val transport = adbTransport
                    if (controlId == null || transport == null) {
                        Log.e(TAG, "sendKey rejected: controlId=$controlId transport=${transport != null}")
                        result.error("NOT_READY", "Control stream not initialized", null)
                        return@setMethodCallHandler
                    }
                    if (!transport.isStreamOpen(controlId)) {
                        Log.e(TAG, "sendKey rejected: control stream $controlId is closed")
                        result.error("STREAM_CLOSED", "Control stream $controlId is closed", null)
                        return@setMethodCallHandler
                    }
                    val action = call.argument<Number>("action")?.toInt() ?: 0
                    val keycode = call.argument<Number>("keycode")?.toInt() ?: 0
                    Log.d(TAG, "sendKey: action=$action keycode=$keycode controlId=$controlId")
                    try {
                        val packet = com.fiscalia.file_cast.scrcpy.ScrcpyControl.buildKeyPacket(action, keycode)
                        transport.enqueueControlWrite(controlId, packet)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "sendKey error: ${e.message}", e)
                        result.error("KEY_ERROR", e.message, null)
                    }
                }
                "sendScroll" -> {
                    val controlId = controlStreamLocalId
                    val transport = adbTransport
                    if (controlId == null || transport == null) {
                        Log.e(TAG, "sendScroll rejected: controlId=$controlId transport=${transport != null}")
                        result.error("NOT_READY", "Control stream not initialized", null)
                        return@setMethodCallHandler
                    }
                    if (!transport.isStreamOpen(controlId)) {
                        Log.e(TAG, "sendScroll rejected: control stream $controlId is closed")
                        result.error("STREAM_CLOSED", "Control stream $controlId is closed", null)
                        return@setMethodCallHandler
                    }
                    val x = call.argument<Number>("x")?.toInt() ?: 0
                    val y = call.argument<Number>("y")?.toInt() ?: 0
                    val scrollX = call.argument<Number>("scrollX")?.toInt() ?: 0
                    val scrollY = call.argument<Number>("scrollY")?.toInt() ?: 0
                    val screenWidth = call.argument<Number>("screenWidth")?.toInt() ?: deviceScreenWidth
                    val screenHeight = call.argument<Number>("screenHeight")?.toInt() ?: deviceScreenHeight
                    try {
                        val packet = com.fiscalia.file_cast.scrcpy.ScrcpyControl.buildScrollPacket(
                            x, y, scrollX, scrollY, screenWidth, screenHeight
                        )
                        transport.enqueueControlWrite(controlId, packet)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "sendScroll error: ${e.message}", e)
                        result.error("SCROLL_ERROR", e.message, null)
                    }
                }
                "setControlStream" -> {
                    val controlId = call.argument<Number>("controlLocalId")?.toInt()
                    val width = call.argument<Number>("screenWidth")?.toInt()
                    val height = call.argument<Number>("screenHeight")?.toInt()
                    val transport = adbTransport
                    val streamOpen = if (controlId != null && transport != null) {
                        transport.isStreamOpen(controlId)
                    } else false
                    Log.d(TAG, "setControlStream: localId=$controlId ${width}x$height streamOpen=$streamOpen")
                    controlStreamLocalId = controlId
                    if (width != null) {
                        scrcpyHeaderWidth = width
                        deviceScreenWidth = width
                    }
                    if (height != null) {
                        scrcpyHeaderHeight = height
                        deviceScreenHeight = height
                    }

                    // Query wm size ONCE (async) to compare with header dimensions
                    Thread {
                        try {
                            if (transport != null && transport.isAdbConnected()) {
                                val output = transport.shellCommand("wm size")
                                wmSizeRaw = output.trim()
                                val overrideMatch = Regex("Override size: (\\d+)x(\\d+)").find(wmSizeRaw)
                                val physicalMatch = Regex("Physical size: (\\d+)x(\\d+)").find(wmSizeRaw)
                                val effectiveMatch = overrideMatch ?: physicalMatch
                                if (effectiveMatch != null) {
                                    wmSizeWidth = effectiveMatch.groupValues[1].toInt()
                                    wmSizeHeight = effectiveMatch.groupValues[2].toInt()
                                } else {
                                    wmSizeWidth = 0
                                    wmSizeHeight = 0
                                }
                                Log.d(TAG, "wm size: raw='$wmSizeRaw' parsed=${wmSizeWidth}x${wmSizeHeight}")

                                // Positional events must use the video size declared by
                                // scrcpy. The server rejects positions whose size does
                                // not match the current encoded frame.
                                if (wmSizeWidth > 0 && wmSizeHeight > 0 &&
                                    (wmSizeWidth != deviceScreenWidth || wmSizeHeight != deviceScreenHeight)) {
                                    Log.w(TAG, "MISMATCH: header=${deviceScreenWidth}x${deviceScreenHeight} vs wm=${wmSizeWidth}x${wmSizeHeight}")
                                    Log.w(TAG, "Keeping scrcpy video size for touch packets")
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "wm size query failed: ${e.message}")
                            wmSizeRaw = "ERROR: ${e.message}"
                        }
                    }.apply {
                        name = "WmSizeQuery"
                        isDaemon = true
                        start()
                    }

                    // Return immediately — wm size runs async, touch will use header dims until wm completes
                    result.success(mapOf(
                        "controlId" to controlId,
                        "streamOpen" to streamOpen,
                        "headerWidth" to width,
                        "headerHeight" to height,
                        "wmSizeWidth" to wmSizeWidth,
                        "wmSizeHeight" to wmSizeHeight,
                        "wmSizeRaw" to wmSizeRaw,
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun captureScreenshot(call: MethodCall, result: MethodChannel.Result) {
        val transport = adbTransport
        if (transport == null || !transport.isAdbConnected()) {
            result.error("NOT_CONNECTED", "ADB no está conectado", null)
            return
        }
        val requisitionId = call.argument<String>("requisitionId") ?: "unknown"
        val sessionId = call.argument<String>("sessionId") ?: "unknown"
        Thread {
            var localId: Int? = null
            try {
                val directory = evidenceDirectory(requisitionId, sessionId)
                val file = File(directory, "captura-${System.currentTimeMillis()}.png")
                val stream = transport.openStream("exec:screencap -p", 10_000L)
                localId = stream.localId
                val digest = MessageDigest.getInstance("SHA-256")
                var total = 0L
                var completed = false
                val deadline = System.currentTimeMillis() + 30_000L
                FileOutputStream(file).use { output ->
                    while (System.currentTimeMillis() < deadline) {
                        val chunk = stream.dataQueue.poll(500, TimeUnit.MILLISECONDS)
                        if (chunk != null) {
                            output.write(chunk)
                            digest.update(chunk)
                            total += chunk.size
                            if (total > 32L * 1024L * 1024L) {
                                throw IllegalStateException("La captura excedió el límite permitido")
                            }
                        } else if (stream.closed.get() && stream.dataQueue.isEmpty()) {
                            completed = true
                            break
                        }
                    }
                    output.flush()
                }
                if (!completed || total < 8 || !hasPngSignature(file)) {
                    file.delete()
                    throw IllegalStateException("El dispositivo no devolvió una imagen PNG válida")
                }
                val metadata = evidenceMetadata(file, digest.digest())
                mainHandler.post { result.success(metadata) }
            } catch (error: Exception) {
                Log.e(TAG, "captureScreenshot error", error)
                mainHandler.post { result.error("CAPTURE_ERROR", error.message ?: "No se pudo capturar", null) }
            } finally {
                localId?.let { transport.closeStream(it) }
            }
        }.apply {
            name = "AdbScreenshot"
            isDaemon = true
            start()
        }
    }

    private fun startScreenRecording(call: MethodCall, result: MethodChannel.Result) {
        if (scrcpyDecoder == null || mirrorVideoWidth <= 0 || mirrorVideoHeight <= 0) {
            result.error("MIRROR_NOT_READY", "El flujo de video aún no está listo", null)
            return
        }
        val requisitionId = call.argument<String>("requisitionId") ?: "unknown"
        val sessionId = call.argument<String>("sessionId") ?: "unknown"
        try {
            val file = File(evidenceDirectory(requisitionId, sessionId), "grabacion-${System.currentTimeMillis()}.mp4")
            synchronized(recorderLock) {
                if (recorder != null || pendingRecordingStartResult != null) {
                    throw IllegalStateException("Ya existe una grabación activa")
                }
                val config = lastCodecConfig
                    ?: throw IllegalStateException("Aún no se recibió la configuración H.264")
                val nextRecorder = ScrcpyRecorder(file, mirrorVideoWidth, mirrorVideoHeight)
                try {
                    nextRecorder.start(config)
                    pendingRecordingStartResult = result
                    val timeout = Runnable { timeoutRecordingStart(result) }
                    recordingStartTimeout = timeout
                    recorder = nextRecorder
                    mainHandler.postDelayed(timeout, RECORDING_START_TIMEOUT_MS)
                } catch (error: Exception) {
                    nextRecorder.abort()
                    throw error
                }
            }
        } catch (error: Exception) {
            Log.e(TAG, "startScreenRecording error", error)
            result.error("RECORDING_ERROR", error.message ?: "No se pudo iniciar la grabación", null)
        }
    }

    private fun completeRecordingStart() {
        val completion = synchronized(recorderLock) {
            val pendingResult = pendingRecordingStartResult ?: return
            val activeRecorder = recorder ?: return
            recordingStartTimeout?.let(mainHandler::removeCallbacks)
            recordingStartTimeout = null
            pendingRecordingStartResult = null
            pendingResult to activeRecorder.file()
        }
        val (pendingResult, file) = completion
        pendingResult.success(
            mapOf(
                "name" to file.name,
                "path" to file.absolutePath,
                "byteLength" to 0,
                "sha256" to "",
            ),
        )
    }

    private fun timeoutRecordingStart(expectedResult: MethodChannel.Result) {
        val timedOut = synchronized(recorderLock) {
            if (pendingRecordingStartResult !== expectedResult) return
            pendingRecordingStartResult = null
            recordingStartTimeout = null
            val activeRecorder = recorder
            recorder = null
            activeRecorder
        }
        try { timedOut?.abort() } catch (error: Exception) {
            Log.e(TAG, "Could not abort recording after start timeout", error)
        }
        expectedResult.error(
            "RECORDING_START_TIMEOUT",
            "El video no entregó un frame clave para iniciar la grabación.",
            null,
        )
    }

    private fun stopScreenRecording(result: MethodChannel.Result) {
        val activeRecorder = synchronized(recorderLock) {
            if (pendingRecordingStartResult != null) null else recorder.also { recorder = null }
        }
        if (activeRecorder == null) {
            result.error("NOT_RECORDING", "No existe una grabación activa", null)
            return
        }
        Thread {
            try {
                val file = activeRecorder.stop()
                val metadata = evidenceMetadata(file, sha256(file))
                mainHandler.post { result.success(metadata) }
            } catch (error: Exception) {
                Log.e(TAG, "stopScreenRecording error", error)
                val detail = error.cause?.message ?: error.message ?: "No se pudo guardar la grabación"
                mainHandler.post { result.error("RECORDING_ERROR", detail, null) }
            }
        }.apply {
            name = "StopScreenRecording"
            isDaemon = true
            start()
        }
    }

    private fun stopRecorderSafely() {
        val stopped = synchronized(recorderLock) {
            recordingStartTimeout?.let(mainHandler::removeCallbacks)
            recordingStartTimeout = null
            val pendingResult = pendingRecordingStartResult
            pendingRecordingStartResult = null
            val activeRecorder = recorder
            recorder = null
            pendingResult to activeRecorder
        }
        val (pendingResult, activeRecorder) = stopped
        try { activeRecorder?.abort() } catch (error: Exception) {
            Log.e(TAG, "Could not abort active recording", error)
        }
        if (pendingResult != null) {
            mainHandler.post {
                pendingResult.error(
                    "RECORDING_INTERRUPTED",
                    "La conexión se interrumpió antes de iniciar la grabación.",
                    null,
                )
            }
        }
    }

    private fun evidenceDirectory(requisitionId: String, sessionId: String): File {
        val safeRequisition = requisitionId.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val safeSession = sessionId.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return File(context.filesDir, "evidence/$safeRequisition/$safeSession").apply { mkdirs() }
    }

    private fun previewDirectory(requisitionId: String, sessionId: String): File {
        val safeRequisition = requisitionId.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val safeSession = sessionId.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return File(context.cacheDir, "file_previews/$safeRequisition/$safeSession")
    }

    private fun evidenceMetadata(file: File, hash: ByteArray): Map<String, Any> = mapOf(
        "name" to file.name,
        "path" to file.absolutePath,
        "byteLength" to file.length(),
        "sha256" to hash.joinToString("") { "%02x".format(it) },
    )

    private fun sha256(file: File): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest()
    }

    private fun hasPngSignature(file: File): Boolean {
        val expected = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
        val actual = ByteArray(expected.size)
        file.inputStream().use { if (it.read(actual) != expected.size) return false }
        return actual.contentEquals(expected)
    }

    private fun setupEventChannel() {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    val devices = getConnectedDevices()
                    if (devices.isNotEmpty()) {
                        sendEvent("initial_devices", devices)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun isOtgSupported(): Boolean {
        // Some OEMs omit the feature declaration even while their framework
        // enumerates peripherals correctly. A live device list is conclusive.
        return context.packageManager.hasSystemFeature("android.hardware.usb.host") ||
            usbManager.deviceList.isNotEmpty()
    }

    private fun getConnectedDevices(): List<Map<String, Any?>> {
        return usbManager.deviceList.values.mapNotNull { device ->
            try {
                deviceToMap(device)
            } catch (error: Exception) {
                // A malformed or permission-protected descriptor must not hide
                // every other device connected behind the same USB hub.
                Log.e(TAG, "Could not inspect USB device ${device.deviceName}", error)
                null
            }
        }
    }

    private fun hasPermission(deviceName: String?): Boolean {
        val device = findDeviceByName(deviceName) ?: return false
        return usbManager.hasPermission(device)
    }

    private fun requestPermission(deviceName: String?, result: MethodChannel.Result) {
        val device: UsbDevice = findDeviceByName(deviceName) ?: run {
            result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
            return
        }

        if (usbManager.hasPermission(device)) {
            result.success(true)
            return
        }

        pendingDevice = device
        usbManager.requestPermission(device, createUsbPermissionIntent())
        result.success(null)
    }

    private fun createUsbPermissionIntent(): PendingIntent {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        return PendingIntent.getBroadcast(
            context,
            0,
            Intent(ACTION_USB_PERMISSION).setPackage(context.packageName),
            flags,
        )
    }

    private fun openDevice(deviceName: String?, result: MethodChannel.Result) {
        val device = findDeviceByName(deviceName)
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
            return
        }

        if (!usbManager.hasPermission(device)) {
            result.error("NO_PERMISSION", "No permission for device: $deviceName", null)
            return
        }

        val connection = usbManager.openDevice(device)
        if (connection == null) {
            result.error("OPEN_FAILED", "Failed to open device: $deviceName", null)
            return
        }

        currentConnection = connection
        result.success(mapOf(
            "deviceName" to device.deviceName,
            "fd" to connection.fileDescriptor
        ))
    }

    private fun connectAdb(deviceName: String?, result: MethodChannel.Result) {
        Log.d(TAG, "=== connectAdb START ===")
        Log.d(TAG, "Device name: $deviceName")
        val existingTransport = adbTransport
        if (existingTransport?.isAdbConnected() == true &&
            pendingHandshakeDevice?.deviceName == deviceName) {
            result.success(mapOf(
                "connected" to true,
                "deviceName" to deviceName,
                "reused" to true,
            ))
            return
        }
        if (existingTransport != null || currentConnection != null || scrcpyDecoder != null) {
            disconnectAdb()
        }
        resultCalled = false
        waitingForReattach = false
        lastAdbLog = ""

        val device = findDeviceByName(deviceName)
        if (device == null) {
            Log.e(TAG, "Device not found: $deviceName")
            result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
            return
        }

        handshakeGeneration += 1
        connectAdbInternal(device, result, handshakeGeneration)
    }

    private fun connectAdbInternal(device: UsbDevice, result: MethodChannel.Result, generation: Int) {
        Log.d(TAG, "=== connectAdbInternal START ===")
        Log.d(TAG, "Device: ${device.deviceName}, VID=0x${Integer.toHexString(device.vendorId)}, PID=0x${Integer.toHexString(device.productId)}")
        resultCalled = false

        UsbAdbTransport.logDeviceInfo(device)

        if (!usbManager.hasPermission(device)) {
            Log.e(TAG, "No permission for device: ${device.deviceName}")
            result.error("NO_PERMISSION", "No permission for device: ${device.deviceName}", null)
            return
        }

        Log.d(TAG, "Permission granted, opening device...")

        // Close previous connection if any
        currentConnection?.close()
        currentConnection = null

        val connection = usbManager.openDevice(device)
        if (connection == null) {
            Log.e(TAG, "Failed to open device: ${device.deviceName}")
            result.error("OPEN_FAILED", "Failed to open device: ${device.deviceName}", null)
            return
        }

        Log.d(TAG, "Device opened, fd: ${connection.fileDescriptor}")
        currentConnection = connection
        pendingHandshakeResult = result
        pendingHandshakeDevice = device
        activeDeviceName = device.deviceName

        Log.d(TAG, "Starting ADB handshake thread...")
        val handshakeThread = Thread {
            try {
                val transport = UsbAdbTransport(device, connection, adbAuth)
                adbTransport = transport

                transport.setOnStateChangedListener { state, message, log ->
                    lastAdbLog = log
                    Log.d(TAG, "ADB state: $state, message: $message")
                    mainHandler.post {
                        sendEvent("adb_state", mapOf(
                            "state" to state,
                            "message" to message,
                            "log" to log
                        ))
                    }
                }

                Log.d(TAG, "Finding ADB interface...")
                if (!transport.findAdbInterface()) {
                    Log.e(TAG, "No ADB interface found!")
                    postResult(result, generation) {
                        result.error("NO_ADB_INTERFACE", "No ADB interface found", null)
                    }
                    return@Thread
                }
                Log.d(TAG, "ADB interface found and claimed")

                Log.d(TAG, "Performing handshake...")
                val success = transport.handshake()
                Log.d(TAG, "Handshake result: $success")

                postResult(result, generation) {
                    if (success) {
                        rememberAdbProductModel(device, transport.getRemoteProductModel())
                        result.success(mapOf(
                            "connected" to true,
                            "deviceName" to device.deviceName
                        ))
                    } else {
                        result.error("HANDSHAKE_FAILED", "ADB handshake failed", null)
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "ADB connection error: ${t.message}", t)
                postResult(result, generation) {
                    result.error("ADB_ERROR", t.message ?: "Unknown error", null)
                }
            }
        }
        handshakeThread.name = "AdbHandshake"
        handshakeThread.isDaemon = true
        handshakeThread.start()

        // Global timeout safety net
        mainHandler.postDelayed({
            if (generation == handshakeGeneration && !resultCalled) {
                Log.e(TAG, "HANDSHAKE GLOBAL TIMEOUT")
                resultCalled = true
                waitingForReattach = false
                adbTransport?.getLog()?.takeIf { it.isNotBlank() }?.let {
                    lastAdbLog = it
                }
                adbTransport?.disconnect()
                adbTransport = null
                connection.close()
                currentConnection = null
                pendingHandshakeResult = null
                result.error("HANDSHAKE_TIMEOUT", "Timeout global de conexion ADB", null)
                sendEvent("adb_state", mapOf(
                    "state" to "error",
                    "message" to "Timeout: el dispositivo no respondio en 40 segundos"
                ))
            }
        }, 40000L)
    }

    private fun postResult(result: MethodChannel.Result, generation: Int, block: () -> Unit) {
        mainHandler.post {
            if (generation == handshakeGeneration && !resultCalled) {
                resultCalled = true
                pendingHandshakeResult = null
                waitingForReattach = false
                block()
            }
        }
    }

    private fun disconnectAdb() {
        handshakeGeneration++
        activeSyncClient?.cancel()
        activeSyncClient = null
        fileTransferRunning.set(false)
        adbTransport?.quietMode = false
        adbTransport?.stopVideoReadLoop()
        adbTransport?.stopControlWriter()
        scrcpyDecoder?.stop()
        scrcpyDecoder = null
        stopRecorderSafely()
        synchronized(recorderLock) {
            lastCodecConfig = null
        }
        mirrorTextureEntry?.release()
        mirrorTextureEntry = null
        controlStreamLocalId = null
        mirrorVideoWidth = 0
        mirrorVideoHeight = 0
        val transport = adbTransport
        transport?.getLog()?.takeIf { it.isNotBlank() }?.let {
            lastAdbLog = it
        }
        adbTransport = null
        transport?.disconnect()
        currentConnection?.close()
        currentConnection = null
        activeDeviceName = null
    }

    private fun findDeviceByName(deviceName: String?): UsbDevice? {
        if (deviceName == null) return null
        return usbManager.deviceList.values.find { it.deviceName == deviceName }
    }

    // ---------------------------------------------------------------------
    // Multi-mirror transport registry
    // ---------------------------------------------------------------------

    private fun connectMultiAdb(
        sourceSessionId: String,
        deviceName: String,
        result: MethodChannel.Result,
    ) {
        val existing = multiSessions[sourceSessionId]
        if (existing?.transport?.isAdbConnected() == true) {
            result.success(mapOf("connected" to true, "reused" to true, "sourceSessionId" to sourceSessionId))
            return
        }
        val device: UsbDevice = findDeviceByName(deviceName) ?: run {
            result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
            return
        }
        if (!hasAdbInterface(device)) {
            result.error("NO_ADB_INTERFACE", "El dispositivo no expone una interfaz ADB", null)
            return
        }
        if (!usbManager.hasPermission(device)) {
            result.error("NO_PERMISSION", "No permission for device: $deviceName", null)
            return
        }
        val firstConnection: android.hardware.usb.UsbDeviceConnection =
            usbManager.openDevice(device) ?: run {
                result.error("OPEN_FAILED", "Failed to open device: $deviceName", null)
                return
            }
        val deviceNamesBeforeHandshake = usbManager.deviceList.keys.toSet()
        Thread {
            var currentDevice = device
            var currentConnection = firstConnection
            var lastError = "ADB handshake failed"

            for (attempt in 0..1) {
                val transport = UsbAdbTransport(currentDevice, currentConnection, adbAuth)
                try {
                    if (!transport.findAdbInterface()) {
                        throw IllegalStateException("No exact ADB interface found")
                    }
                    if (!transport.handshake()) {
                        throw IllegalStateException("ADB handshake failed")
                    }
                    rememberAdbProductModel(currentDevice, transport.getRemoteProductModel())
                    val state = MultiMirrorState(
                        sourceSessionId = sourceSessionId,
                        device = currentDevice,
                        connection = currentConnection,
                        transport = transport,
                    )
                    multiSessions[sourceSessionId]?.let {
                        disconnectMultiSession(sourceSessionId, notify = false)
                    }
                    multiSessions[sourceSessionId] = state
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "connected" to true,
                                "sourceSessionId" to sourceSessionId,
                                "deviceName" to currentDevice.deviceName,
                                "rsaFingerprint" to adbAuth.getKeyFingerprint(),
                            ),
                        )
                        sendEvent("multi_adb_state", mapOf(
                            "sourceSessionId" to sourceSessionId,
                            "state" to "connected",
                            "deviceName" to currentDevice.deviceName,
                        ))
                    }
                    return@Thread
                } catch (error: Exception) {
                    lastError = error.message ?: "No se pudo conectar ADB"
                    transport.disconnect()
                    currentConnection.close()
                }

                if (attempt == 0) {
                    mainHandler.post {
                        sendEvent("multi_adb_state", mapOf(
                            "sourceSessionId" to sourceSessionId,
                            "state" to "reenumerating",
                            "message" to "Esperando la reconexión posterior a la autorización RSA",
                        ))
                    }
                    val reenumerated = waitForMultiAdbDevice(
                        previous = currentDevice,
                        deviceNamesBeforeHandshake = deviceNamesBeforeHandshake,
                        timeoutMs = 15_000L,
                    )
                    if (reenumerated != null) {
                        val reopened = usbManager.openDevice(reenumerated)
                        if (reopened != null) {
                            currentDevice = reenumerated
                            currentConnection = reopened
                            continue
                        }
                        lastError = "El dispositivo reapareció, pero Android no pudo abrirlo"
                    } else {
                        lastError =
                            "El dispositivo no reapareció con permiso ADB después de la autorización RSA"
                    }
                }
            }

            mainHandler.post {
                result.error("MULTI_ADB_ERROR", lastError, null)
                sendEvent("multi_adb_state", mapOf(
                    "sourceSessionId" to sourceSessionId,
                    "state" to "error",
                    "message" to lastError,
                ))
            }
        }.apply {
            name = "MultiAdbHandshake-$sourceSessionId"
            isDaemon = true
            start()
        }
    }

    private fun waitForMultiAdbDevice(
        previous: UsbDevice,
        deviceNamesBeforeHandshake: Set<String>,
        timeoutMs: Long,
    ): UsbDevice? {
        val previousSerial = if (usbManager.hasPermission(previous)) {
            safeUsbString { previous.serialNumber }
        } else {
            null
        }
        val deadline = System.currentTimeMillis() + timeoutMs
        val permissionRequests = mutableSetOf<String>()
        while (System.currentTimeMillis() < deadline) {
            val activeNames = multiSessions.values.map { it.device.deviceName }.toSet()
            val candidates = usbManager.deviceList.values.filter { candidate ->
                candidate.deviceName !in activeNames &&
                    candidate.vendorId == previous.vendorId &&
                    candidate.productId == previous.productId &&
                    hasAdbInterface(candidate)
            }
            val serialMatch = previousSerial?.let { expected ->
                candidates.firstOrNull { candidate ->
                    usbManager.hasPermission(candidate) &&
                        safeUsbString { candidate.serialNumber } == expected
                }
            }
            val match = serialMatch
                ?: candidates.firstOrNull { it.deviceName == previous.deviceName }
                ?: candidates.filter {
                    it.deviceName !in deviceNamesBeforeHandshake
                }.singleOrNull()
                ?: candidates.singleOrNull()
            if (match != null) {
                if (usbManager.hasPermission(match)) return match
                if (permissionRequests.add(match.deviceName)) {
                    mainHandler.post {
                        sendEvent("multi_adb_state", mapOf(
                            "state" to "permission_required",
                            "deviceName" to match.deviceName,
                            "message" to "Confirma nuevamente el acceso USB después de la reenumeración ADB",
                        ))
                        try {
                            usbManager.requestPermission(match, createUsbPermissionIntent())
                        } catch (error: Exception) {
                            Log.e(TAG, "Could not request permission after ADB re-enumeration", error)
                        }
                    }
                }
            }
            try {
                Thread.sleep(350L)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                return null
            }
        }
        return null
    }

    private fun multiState(sourceSessionId: String, result: MethodChannel.Result): MultiMirrorState? {
        val state = multiSessions[sourceSessionId]
        if (state == null || !state.transport.isAdbConnected()) {
            result.error("NOT_CONNECTED", "La sesión multi no está conectada", null)
            return null
        }
        return state
    }

    private fun multiPushFile(sourceSessionId: String, localPath: String, remotePath: String, result: MethodChannel.Result) {
        val state = multiState(sourceSessionId, result) ?: return
        Thread {
            try {
                val success = state.transport.pushFile(localPath, remotePath)
                mainHandler.post { result.success(mapOf("success" to success, "sourceSessionId" to sourceSessionId)) }
            } catch (error: Exception) {
                mainHandler.post { result.error("MULTI_PUSH_ERROR", error.message ?: "No se pudo preparar scrcpy", null) }
            }
        }.apply { name = "MultiPushFile-$sourceSessionId"; isDaemon = true; start() }
    }

    private fun multiStartPersistentShell(sourceSessionId: String, command: String, result: MethodChannel.Result) {
        val state = multiState(sourceSessionId, result) ?: return
        Thread {
            try {
                val localId = state.transport.startPersistentShell(command)
                state.serverShellLocalId = localId
                mainHandler.post { result.success(mapOf("localId" to localId, "sourceSessionId" to sourceSessionId)) }
            } catch (error: Exception) {
                mainHandler.post { result.error("MULTI_SHELL_ERROR", error.message ?: "No se pudo iniciar scrcpy", null) }
            }
        }.apply { name = "MultiShell-$sourceSessionId"; isDaemon = true; start() }
    }

    private fun multiShellCommand(sourceSessionId: String, command: String, result: MethodChannel.Result) {
        val state = multiState(sourceSessionId, result) ?: return
        Thread {
            try {
                val output = state.transport.shellCommand(command)
                mainHandler.post { result.success(mapOf("output" to output, "sourceSessionId" to sourceSessionId)) }
            } catch (error: Exception) {
                mainHandler.post { result.error("MULTI_SHELL_ERROR", error.message ?: "No se pudo ejecutar el comando", null) }
            }
        }.apply { name = "MultiShellCommand-$sourceSessionId"; isDaemon = true; start() }
    }

    private fun multiConnectScrcpySockets(sourceSessionId: String, result: MethodChannel.Result) {
        val state = multiState(sourceSessionId, result) ?: return
        Thread {
            var videoLocalId: Int? = null
            var controlLocalId: Int? = null
            try {
                val video = state.transport.openStream("localabstract:scrcpy", 10_000L)
                videoLocalId = video.localId
                val control = state.transport.openStream("localabstract:scrcpy", 10_000L)
                controlLocalId = control.localId
                val dummy = state.transport.readStreamExact(video.localId, 1)
                    ?: throw IllegalStateException("scrcpy no devolvió el encabezado")
                val nameBytes = state.transport.readStreamExact(video.localId, 64)
                    ?: throw IllegalStateException("scrcpy no devolvió el nombre")
                val nameEnd = nameBytes.indexOfFirst { it.toInt() == 0 }
                val deviceName = String(nameBytes, 0, if (nameEnd > 0) nameEnd else 64, Charsets.UTF_8)
                val meta = state.transport.readStreamExact(video.localId, 12)
                    ?: throw IllegalStateException("scrcpy no devolvió las dimensiones")
                val buffer = ByteBuffer.wrap(meta).order(ByteOrder.BIG_ENDIAN)
                buffer.int // codec id
                val width = buffer.int
                val height = buffer.int
                state.videoStreamLocalId = video.localId
                state.controlStreamLocalId = control.localId
                state.videoWidth = width
                state.videoHeight = height
                state.screenWidth = width
                state.screenHeight = height
                mainHandler.post {
                    result.success(mapOf(
                        "sourceSessionId" to sourceSessionId,
                        "deviceName" to deviceName,
                        "width" to width,
                        "height" to height,
                        "localId" to video.localId,
                        "controlLocalId" to control.localId,
                    ))
                }
            } catch (error: Exception) {
                controlLocalId?.let { state.transport.closeStream(it) }
                videoLocalId?.let { state.transport.closeStream(it) }
                mainHandler.post { result.error("MULTI_SCRCPY_ERROR", error.message ?: "No se pudo abrir scrcpy", null) }
            }
        }.apply { name = "MultiScrcpySockets-$sourceSessionId"; isDaemon = true; start() }
    }

    private fun multiCreateMirrorTexture(sourceSessionId: String, result: MethodChannel.Result) {
        val state = multiState(sourceSessionId, result) ?: return
        if (state.textureEntry != null) {
            result.success(mapOf("textureId" to state.textureEntry!!.id(), "reused" to true))
            return
        }
        try {
            val entry = flutterEngine.renderer.createSurfaceTexture()
            state.textureEntry = entry
            result.success(mapOf("textureId" to entry.id(), "sourceSessionId" to sourceSessionId))
        } catch (error: Exception) {
            result.error("MULTI_TEXTURE_ERROR", error.message ?: "No se pudo crear la textura", null)
        }
    }

    private fun multiStartMirror(
        sourceSessionId: String,
        width: Int,
        height: Int,
        localId: Int,
        result: MethodChannel.Result,
    ) {
        val state = multiState(sourceSessionId, result) ?: return
        val entry = state.textureEntry
        if (entry == null) {
            result.error("NOT_READY", "La textura multi no está inicializada", null)
            return
        }
        if (state.decoder != null) {
            result.error("MIRROR_ALREADY_ACTIVE", "El mirror multi ya está activo", null)
            return
        }
        Thread {
            try {
                val surfaceTexture = entry.surfaceTexture()
                state.videoWidth = width
                state.videoHeight = height
                state.screenWidth = width
                state.screenHeight = height
                surfaceTexture.setDefaultBufferSize(width, height)
                if (!state.transport.enableVideoFlowControl(localId)) {
                    throw IllegalStateException("El stream de video $localId ya no está disponible")
                }
                val decoder = ScrcpyDecoder()
                state.decoder = decoder
                val started = decoder.start(
                    width = width,
                    height = height,
                    surface = Surface(surfaceTexture),
                    onOutputSizeChanged = { outputWidth, outputHeight ->
                        state.videoWidth = outputWidth
                        state.videoHeight = outputHeight
                        state.screenWidth = outputWidth
                        state.screenHeight = outputHeight
                        mainHandler.post {
                            surfaceTexture.setDefaultBufferSize(outputWidth, outputHeight)
                            sendEvent("multi_mirror_state", mapOf(
                                "sourceSessionId" to sourceSessionId,
                                "state" to "video_size",
                                "width" to outputWidth,
                                "height" to outputHeight,
                            ))
                        }
                    },
                )
                if (!started) {
                    val codecError = decoder.getLastStartError()
                        ?: "El decodificador H.264 del inspector no aceptó ${width}x$height"
                    decoder.stop()
                    state.decoder = null
                    mainHandler.post {
                        result.error("MULTI_CODEC_ERROR", codecError, mapOf(
                            "width" to width,
                            "height" to height,
                            "retryableAtLowerResolution" to true,
                        ))
                    }
                    return@Thread
                }
                state.transport.quietMode = true
                state.transport.startVideoReadLoop(
                    localId = localId,
                    onPacket = { headerValue, payload ->
                        decoder.feedPacket(payload, headerValue)
                        synchronized(state.recorderLock) {
                            if ((headerValue and FLAG_VIDEO_CONFIG) != 0L) {
                                state.lastCodecConfig = (state.lastCodecConfig ?: byteArrayOf()) + payload
                            } else {
                                state.recorder?.writePacket(headerValue, payload)
                            }
                        }
                    },
                    onError = { message ->
                        mainHandler.post { sendEvent("multi_mirror_state", mapOf(
                            "sourceSessionId" to sourceSessionId,
                            "state" to "error",
                            "message" to message,
                        )) }
                    },
                )
                mainHandler.post { result.success(mapOf("started" to true, "sourceSessionId" to sourceSessionId)) }
            } catch (error: Exception) {
                state.decoder?.stop()
                state.decoder = null
                mainHandler.post { result.error("MULTI_MIRROR_ERROR", error.message ?: "No se pudo iniciar el mirror", null) }
            }
        }.apply { name = "MultiStartMirror-$sourceSessionId"; isDaemon = true; start() }
    }

    private fun stopMultiMirror(sourceSessionId: String) {
        val state = multiSessions[sourceSessionId] ?: return
        state.transport.quietMode = false
        state.transport.stopVideoReadLoop()
        state.transport.stopControlWriter()
        state.decoder?.stop()
        state.decoder = null
        synchronized(state.recorderLock) {
            state.recorder?.abort()
            state.recorder = null
            state.lastCodecConfig = null
        }
        state.textureEntry?.release()
        state.textureEntry = null
        listOfNotNull(
            state.videoStreamLocalId,
            state.controlStreamLocalId,
            state.serverShellLocalId,
        ).distinct().forEach { localId ->
            try {
                state.transport.closeStream(localId)
            } catch (error: Exception) {
                Log.w(TAG, "Could not close multi stream $localId: ${error.message}")
            }
        }
        state.videoStreamLocalId = null
        state.controlStreamLocalId = null
        state.serverShellLocalId = null
    }

    private fun disconnectMultiSession(sourceSessionId: String, notify: Boolean) {
        stopMultiMirror(sourceSessionId)
        val state = multiSessions.remove(sourceSessionId) ?: return
        state.transport.disconnect()
        state.connection.close()
        if (notify) {
            sendEvent("multi_session_state", mapOf("sourceSessionId" to sourceSessionId, "state" to "disconnected"))
        }
    }

    private fun multiSendTouch(call: MethodCall, result: MethodChannel.Result) {
        val sourceSessionId = call.argument<String>("sourceSessionId")
        val state = sourceSessionId?.let { multiSessions[it] }
        val controlId = state?.controlStreamLocalId
        if (state == null || controlId == null) {
            result.error("NOT_READY", "Control multi no inicializado", null)
            return
        }
        try {
            val action = call.argument<Number>("action")?.toInt() ?: 0
            val pointerId = call.argument<Number>("pointerId")?.toLong() ?: 1L
            val x = call.argument<Number>("x")?.toInt() ?: 0
            val y = call.argument<Number>("y")?.toInt() ?: 0
            val pressure = if (action == 1) 0 else 0xFFFF
            val packet = com.fiscalia.file_cast.scrcpy.ScrcpyControl.buildTouchPacket(
                action, pointerId, x, y, state.screenWidth, state.screenHeight, pressure,
            )
            state.transport.enqueueControlWrite(controlId, packet)
            result.success(true)
        } catch (error: Exception) {
            result.error("TOUCH_ERROR", error.message ?: "No se pudo enviar el toque", null)
        }
    }

    private fun multiSendKey(call: MethodCall, result: MethodChannel.Result) {
        val sourceSessionId = call.argument<String>("sourceSessionId")
        val state = sourceSessionId?.let { multiSessions[it] }
        val controlId = state?.controlStreamLocalId
        if (state == null || controlId == null) {
            result.error("NOT_READY", "Control multi no inicializado", null)
            return
        }
        try {
            val packet = com.fiscalia.file_cast.scrcpy.ScrcpyControl.buildKeyPacket(
                call.argument<Number>("action")?.toInt() ?: 0,
                call.argument<Number>("keycode")?.toInt() ?: 0,
            )
            state.transport.enqueueControlWrite(controlId, packet)
            result.success(true)
        } catch (error: Exception) {
            result.error("KEY_ERROR", error.message ?: "No se pudo enviar la tecla", null)
        }
    }

    private fun multiSendScroll(call: MethodCall, result: MethodChannel.Result) {
        val sourceSessionId = call.argument<String>("sourceSessionId")
        val state = sourceSessionId?.let { multiSessions[it] }
        val controlId = state?.controlStreamLocalId
        if (state == null || controlId == null) {
            result.error("NOT_READY", "Control multi no inicializado", null)
            return
        }
        try {
            val packet = com.fiscalia.file_cast.scrcpy.ScrcpyControl.buildScrollPacket(
                call.argument<Number>("x")?.toInt() ?: 0,
                call.argument<Number>("y")?.toInt() ?: 0,
                call.argument<Number>("scrollX")?.toInt() ?: 0,
                call.argument<Number>("scrollY")?.toInt() ?: 0,
                state.screenWidth,
                state.screenHeight,
            )
            state.transport.enqueueControlWrite(controlId, packet)
            result.success(true)
        } catch (error: Exception) {
            result.error("SCROLL_ERROR", error.message ?: "No se pudo enviar el scroll", null)
        }
    }

    private fun multiCaptureScreenshot(call: MethodCall, result: MethodChannel.Result) {
        val sourceSessionId = call.argument<String>("sourceSessionId")
        val state = sourceSessionId?.let { multiSessions[it] }
        if (state == null || !state.transport.isAdbConnected()) {
            result.error("NOT_CONNECTED", "La sesión multi no está conectada", null)
            return
        }
        val requisitionId = call.argument<String>("requisitionId") ?: "unknown"
        val sessionId = call.argument<String>("sessionId") ?: "unknown"
        Thread {
            var localId: Int? = null
            try {
                val file = File(evidenceDirectory(requisitionId, sessionId), "captura-${sourceSessionId}-${System.currentTimeMillis()}.png")
                val stream = state.transport.openStream("exec:screencap -p", 10_000L)
                localId = stream.localId
                val digest = MessageDigest.getInstance("SHA-256")
                var total = 0L
                FileOutputStream(file).use { output ->
                    while (!stream.closed.get() || stream.dataQueue.isNotEmpty()) {
                        val chunk = stream.dataQueue.poll(500, TimeUnit.MILLISECONDS) ?: break
                        output.write(chunk)
                        digest.update(chunk)
                        total += chunk.size
                        if (total > 32L * 1024L * 1024L) throw IllegalStateException("La captura excedió el límite permitido")
                    }
                    output.flush()
                }
                if (total < 8 || !hasPngSignature(file)) throw IllegalStateException("El dispositivo no devolvió una imagen PNG válida")
                mainHandler.post { result.success(evidenceMetadata(file, digest.digest())) }
            } catch (error: Exception) {
                mainHandler.post { result.error("CAPTURE_ERROR", error.message ?: "No se pudo capturar", null) }
            } finally {
                localId?.let { state.transport.closeStream(it) }
            }
        }.apply { name = "MultiScreenshot-$sourceSessionId"; isDaemon = true; start() }
    }

    private fun multiStartScreenRecording(call: MethodCall, result: MethodChannel.Result) {
        val sourceSessionId = call.argument<String>("sourceSessionId")
        val state = sourceSessionId?.let { multiSessions[it] }
        if (state == null || state.decoder == null || state.videoWidth <= 0 || state.videoHeight <= 0) {
            result.error("MIRROR_NOT_READY", "El mirror multi aún no está listo", null)
            return
        }
        val config = synchronized(state.recorderLock) { state.lastCodecConfig }
        if (config == null) {
            result.error("RECORDING_NOT_READY", "Aún no se recibió la configuración H.264", null)
            return
        }
        val requisitionId = call.argument<String>("requisitionId") ?: "unknown"
        val sessionId = call.argument<String>("sessionId") ?: "unknown"
        try {
            synchronized(state.recorderLock) {
                if (state.recorder != null) throw IllegalStateException("Ya existe una grabación activa")
                val file = File(evidenceDirectory(requisitionId, sessionId), "grabacion-${sourceSessionId}-${System.currentTimeMillis()}.mp4")
                state.recorder = ScrcpyRecorder(file, state.videoWidth, state.videoHeight).also { it.start(config) }
                result.success(evidenceMetadata(file, byteArrayOf()))
            }
        } catch (error: Exception) {
            result.error("RECORDING_ERROR", error.message ?: "No se pudo iniciar la grabación", null)
        }
    }

    private fun multiStopScreenRecording(call: MethodCall, result: MethodChannel.Result) {
        val sourceSessionId = call.argument<String>("sourceSessionId")
        val state = sourceSessionId?.let { multiSessions[it] }
        if (state == null) {
            result.error("NOT_CONNECTED", "La sesión multi no está conectada", null)
            return
        }
        val recorder = synchronized(state.recorderLock) { state.recorder.also { state.recorder = null } }
        if (recorder == null) {
            result.error("NOT_RECORDING", "No existe una grabación activa", null)
            return
        }
        Thread {
            try {
                val file = recorder.stop()
                mainHandler.post { result.success(evidenceMetadata(file, sha256(file))) }
            } catch (error: Exception) {
                mainHandler.post { result.error("RECORDING_ERROR", error.message ?: "No se pudo guardar la grabación", null) }
            }
        }.apply { name = "MultiStopRecording-$sourceSessionId"; isDaemon = true; start() }
    }

    private fun multiGetMirrorLog(call: MethodCall, result: MethodChannel.Result) {
        val sourceSessionId = call.argument<String>("sourceSessionId")
        val state = sourceSessionId?.let { multiSessions[it] }
        if (state == null) {
            result.success(mapOf("log" to "(multi session not found)"))
            return
        }
        val log = buildString {
            appendLine("Source: $sourceSessionId device=${state.device.deviceName}")
            appendLine("Decoder: started=${state.decoder?.isStarted() == true} frames=${state.decoder?.getFrameCount() ?: 0}")
            appendLine("Video: ${state.videoWidth}x${state.videoHeight} control=${state.controlStreamLocalId}")
            appendLine("Transport: ${state.transport.getControlWriteStats()}")
            append(state.transport.getLog())
        }
        result.success(mapOf("log" to log, "videoWidth" to state.videoWidth, "videoHeight" to state.videoHeight))
    }

    private fun deviceToMap(device: UsbDevice): Map<String, Any?> {
        val hasAdb = hasAdbInterface(device)
        val hasPermission = usbManager.hasPermission(device)
        val interfaces = (0 until device.interfaceCount).map { index ->
            val iface = device.getInterface(index)
            mapOf(
                "index" to index,
                "class" to iface.interfaceClass,
                "subclass" to iface.interfaceSubclass,
                "protocol" to iface.interfaceProtocol,
                "endpointCount" to iface.endpointCount,
            )
        }
        val interfaceClasses = interfaces.mapNotNull { it["class"] as? Int }.toSet()
        return mapOf(
            "deviceName" to device.deviceName,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            // Android 10+ throws SecurityException when serialNumber is read
            // before UsbManager permission is granted. Some vendors protect
            // the string descriptors as well, so read all three defensively.
            "manufacturerName" to safeUsbString { device.manufacturerName },
            "productName" to safeUsbString { device.productName },
            "adbProductModel" to cachedAdbProductModel(device, hasPermission),
            "serialNumber" to if (hasPermission) {
                safeUsbString { device.serialNumber }
            } else {
                null
            },
            "deviceClass" to device.deviceClass,
            "deviceSubclass" to device.deviceSubclass,
            "deviceProtocol" to device.deviceProtocol,
            "hasPermission" to hasPermission,
            "hasAdbInterface" to hasAdb,
            "deviceType" to when {
                hasAdb -> "android_adb"
                device.deviceClass == 9 || 9 in interfaceClasses -> "hub"
                device.deviceClass == 6 || 6 in interfaceClasses -> "mtp"
                device.deviceClass == 3 || 3 in interfaceClasses -> "hid"
                device.deviceClass == 14 || 14 in interfaceClasses -> "video"
                else -> "other"
            },
            "interfaces" to interfaces,
        )
    }

    private fun rememberAdbProductModel(device: UsbDevice, productModel: String?) {
        val model = productModel?.trim()?.takeIf { it.isNotEmpty() } ?: return
        val editor = adbDeviceMetadata.edit()
            .putString(adbMetadataDeviceKey(device), model)
        if (usbManager.hasPermission(device)) {
            safeUsbString { device.serialNumber }
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?.let { serial ->
                    editor.putString(adbMetadataSerialKey(device, serial), model)
                }
        }
        editor.apply()
    }

    private fun cachedAdbProductModel(device: UsbDevice, hasPermission: Boolean): String? {
        if (hasPermission) {
            val bySerial = safeUsbString { device.serialNumber }
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
                ?.let { serial ->
                    adbDeviceMetadata.getString(adbMetadataSerialKey(device, serial), null)
                }
            if (!bySerial.isNullOrBlank()) return bySerial
        }
        return adbDeviceMetadata.getString(adbMetadataDeviceKey(device), null)
    }

    private fun adbMetadataDeviceKey(device: UsbDevice): String =
        "device:${device.vendorId}:${device.productId}:${device.deviceName}"

    private fun adbMetadataSerialKey(device: UsbDevice, serial: String): String =
        "serial:${device.vendorId}:${device.productId}:$serial"

    private fun safeUsbString(reader: () -> String?): String? {
        return try {
            reader()
        } catch (_: SecurityException) {
            null
        } catch (_: UnsupportedOperationException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun hasAdbInterface(device: UsbDevice): Boolean {
        for (index in 0 until device.interfaceCount) {
            val iface = device.getInterface(index)
            if (iface.interfaceClass == 0xFF &&
                iface.interfaceSubclass == 0x42 &&
                iface.interfaceProtocol == 0x01) {
                return true
            }
        }
        return false
    }

    private fun sendDeviceConnected(device: UsbDevice) {
        sendEvent("device_connected", deviceToMap(device))
    }

    private fun sendEvent(type: String, data: Any?) {
        val event = mapOf(
            "type" to type,
            "data" to data
        )
        eventSink?.success(event)
    }

    private fun postTransferEvent(data: Map<String, Any>) {
        mainHandler.post { sendEvent("file_transfer", data) }
    }
}

private class MultiMirrorState(
    val sourceSessionId: String,
    val device: UsbDevice,
    val connection: android.hardware.usb.UsbDeviceConnection,
    val transport: UsbAdbTransport,
) {
    var serverShellLocalId: Int? = null
    var videoStreamLocalId: Int? = null
    var controlStreamLocalId: Int? = null
    var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    var decoder: ScrcpyDecoder? = null
    var videoWidth: Int = 0
    var videoHeight: Int = 0
    var screenWidth: Int = 0
    var screenHeight: Int = 0
    var lastCodecConfig: ByteArray? = null
    var recorder: ScrcpyRecorder? = null
    val recorderLock = Any()

    fun toMap(): Map<String, Any?> = mapOf(
        "sourceSessionId" to sourceSessionId,
        "deviceName" to device.deviceName,
        "connected" to transport.isAdbConnected(),
        "mirrorActive" to (decoder?.isStarted() == true),
        "textureId" to textureEntry?.id(),
        "videoWidth" to videoWidth,
        "videoHeight" to videoHeight,
    )
}
