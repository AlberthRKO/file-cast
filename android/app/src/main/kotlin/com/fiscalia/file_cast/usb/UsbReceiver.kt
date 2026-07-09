package com.fiscalia.file_cast.usb

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager

class UsbReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE) ?: return

        when (intent.action) {
            UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                // Device attached - the plugin will handle this via its own receiver
            }
            UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                // Device detached - the plugin will handle this via its own receiver
            }
        }
    }
}
