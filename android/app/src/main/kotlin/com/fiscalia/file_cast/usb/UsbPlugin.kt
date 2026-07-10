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
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.fiscalia.file_cast.adb.AdbAuth

class UsbPlugin(private val context: Context, private val flutterEngine: FlutterEngine) {

    companion object {
        private const val TAG = "UsbPlugin"
        private const val METHOD_CHANNEL = "com.fiscalia.file_cast/usb"
        private const val EVENT_CHANNEL = "com.fiscalia.file_cast/usb/events"
        private const val ACTION_USB_PERMISSION = "com.fiscalia.file_cast.USB_PERMISSION"
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
    private var waitingForReattach = false

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
                                connectAdbInternal(device, savedResult!!)
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

                        disconnectAdb()
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
                "getAdbState" -> {
                    result.success(mapOf(
                        "connected" to (adbTransport?.isAdbConnected() ?: false)
                    ))
                }
                else -> result.notImplemented()
            }
        }
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
        return context.packageManager.hasSystemFeature("android.hardware.usb.host")
    }

    private fun getConnectedDevices(): List<Map<String, Any?>> {
        return usbManager.deviceList.values.map { deviceToMap(it) }
    }

    private fun hasPermission(deviceName: String?): Boolean {
        val device = findDeviceByName(deviceName) ?: return false
        return usbManager.hasPermission(device)
    }

    private fun requestPermission(deviceName: String?, result: MethodChannel.Result) {
        val device = findDeviceByName(deviceName)
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
            return
        }

        if (usbManager.hasPermission(device)) {
            result.success(true)
            return
        }

        pendingDevice = device
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val permissionIntent = PendingIntent.getBroadcast(
            context, 0, Intent(ACTION_USB_PERMISSION), flags
        )

        usbManager.requestPermission(device, permissionIntent)
        result.success(null)
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
        resultCalled = false
        waitingForReattach = false

        val device = findDeviceByName(deviceName)
        if (device == null) {
            Log.e(TAG, "Device not found: $deviceName")
            result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
            return
        }

        connectAdbInternal(device, result)
    }

    private fun connectAdbInternal(device: UsbDevice, result: MethodChannel.Result) {
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

        Log.d(TAG, "Starting ADB handshake thread...")
        val handshakeThread = Thread {
            try {
                val transport = UsbAdbTransport(device, connection, adbAuth)
                adbTransport = transport

                transport.setOnStateChangedListener { state, message, log ->
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
                    postResult(result) {
                        result.error("NO_ADB_INTERFACE", "No ADB interface found", null)
                    }
                    return@Thread
                }
                Log.d(TAG, "ADB interface found and claimed")

                Log.d(TAG, "Performing handshake...")
                val success = transport.handshake()
                Log.d(TAG, "Handshake result: $success")

                postResult(result) {
                    if (success) {
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
                postResult(result) {
                    result.error("ADB_ERROR", t.message ?: "Unknown error", null)
                }
            }
        }
        handshakeThread.name = "AdbHandshake"
        handshakeThread.isDaemon = true
        handshakeThread.start()

        // Global timeout safety net
        mainHandler.postDelayed({
            if (!resultCalled) {
                Log.e(TAG, "HANDSHAKE GLOBAL TIMEOUT")
                resultCalled = true
                waitingForReattach = false
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

    private fun postResult(result: MethodChannel.Result, block: () -> Unit) {
        mainHandler.post {
            if (!resultCalled) {
                resultCalled = true
                pendingHandshakeResult = null
                waitingForReattach = false
                block()
            }
        }
    }

    private fun disconnectAdb() {
        val transport = adbTransport
        adbTransport = null
        currentConnection?.close()
        currentConnection = null
        transport?.disconnect()
    }

    private fun findDeviceByName(deviceName: String?): UsbDevice? {
        if (deviceName == null) return null
        return usbManager.deviceList.values.find { it.deviceName == deviceName }
    }

    private fun deviceToMap(device: UsbDevice): Map<String, Any?> {
        return mapOf(
            "deviceName" to device.deviceName,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "manufacturerName" to device.manufacturerName,
            "productName" to device.productName,
            "serialNumber" to device.serialNumber,
            "deviceClass" to device.deviceClass,
            "deviceSubclass" to device.deviceSubclass,
            "deviceProtocol" to device.deviceProtocol,
            "hasPermission" to usbManager.hasPermission(device)
        )
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
}
