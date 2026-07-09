package com.fiscalia.file_cast.usb

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class UsbPlugin(private val context: Context, private val flutterEngine: FlutterEngine) {

    companion object {
        private const val METHOD_CHANNEL = "com.fiscalia.file_cast/usb"
        private const val EVENT_CHANNEL = "com.fiscalia.file_cast/usb/events"
        private const val ACTION_USB_PERMISSION = "com.fiscalia.file_cast.USB_PERMISSION"
    }

    private val usbManager: UsbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var eventSink: EventChannel.EventSink? = null
    private var pendingDevice: UsbDevice? = null

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
                        sendEvent("device_attached", deviceToMap(device))
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                    if (device != null) {
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
                else -> result.notImplemented()
            }
        }
    }

    private fun setupEventChannel() {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    // Notify about already connected devices
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
        result.success(null) // Will be notified via broadcast
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

        // Return connection descriptor for further use
        result.success(mapOf(
            "deviceName" to device.deviceName,
            "fd" to connection.fileDescriptor
        ))
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            eventSink?.success(event)
        } else {
            eventSink?.success(event)
        }
    }
}
