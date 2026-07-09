package com.fiscalia.file_cast

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.fiscalia.file_cast.usb.UsbPlugin

class MainActivity : FlutterActivity() {

    private var usbPlugin: UsbPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        usbPlugin = UsbPlugin(this, flutterEngine)
        usbPlugin?.register()
    }

    override fun onDestroy() {
        usbPlugin?.unregister()
        super.onDestroy()
    }
}
