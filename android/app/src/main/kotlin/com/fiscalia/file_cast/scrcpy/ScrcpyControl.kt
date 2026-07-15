package com.fiscalia.file_cast.scrcpy

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Builds scrcpy control packets (touch, key, scroll) per v2.7 protocol.
 * Reference: https://github.com/Genymobile/scrcpy/blob/master/app/src/main/java/com/genymobile/scrcpy/ControlMessage.java
 *
 * All packets are written to the control ADB stream (second socket).
 */
object ScrcpyControl {

    // Message types (first byte of control packet)
    const val TYPE_INJECT_KEY = 0
    const val TYPE_INJECT_TEXT = 1
    const val TYPE_INJECT_TOUCH = 2
    const val TYPE_INJECT_SCROLL = 3
    const val TYPE_BACK_OR_SCREEN_ON = 4
    const val TYPE_GET_CLIPBOARD = 5
    const val TYPE_SET_CLIPBOARD = 6
    const val TYPE_SET_SCREEN_POWER_MODE = 7
    const val TYPE_APP_SWITCH = 8

    // Android KeyEvent action
    const val ACTION_DOWN = 0
    const val ACTION_UP = 1

    // Android MotionEvent action
    const val ACTION_DOWN_TOUCH = 0
    const val ACTION_UP_TOUCH = 1
    const val ACTION_MOVE = 2

    // Pointer id for single touch
    private const val POINTER_ID = 1L

    /**
     * Build a touch event packet (32 bytes).
     *
     * scrcpy v2.7 INJECT_TOUCH_EVENT format (serialize_touch_event):
     * type(1) + action(1) + pointer_id(8) + x(4) + y(4) + screen_width(2) +
     * screen_height(2) + pressure(2) + action_button(4) + buttons(4) = 32
     *
     * @param action ACTION_DOWN_TOUCH, ACTION_UP_TOUCH, or ACTION_MOVE
     * @param x Touch X in device screen coordinates
     * @param y Touch Y in device screen coordinates
     * @param screenWidth Device screen width
     * @param screenHeight Device screen height
     * @param pressure Pressure (0xFFFF for max)
     */
    fun buildTouchPacket(
        action: Int,
        x: Int,
        y: Int,
        screenWidth: Int,
        screenHeight: Int,
        pressure: Int = 0xFFFF
    ): ByteArray {
        val buf = ByteBuffer.allocate(32).order(ByteOrder.BIG_ENDIAN)
        buf.put(TYPE_INJECT_TOUCH.toByte())        // 1
        buf.put(action.toByte())                    // 1
        buf.putLong(POINTER_ID)                     // 8
        buf.putInt(x)                               // 4
        buf.putInt(y)                               // 4
        buf.putShort(screenWidth.toShort())         // 2
        buf.putShort(screenHeight.toShort())        // 2
        buf.putShort(pressure.toShort())            // 2
        buf.putInt(0)                               // 4 action_button
        buf.putInt(0)                               // 4 buttons
        return buf.array()                          // total: 32
    }

    /**
     * Build a key event packet (14 bytes).
     *
     * @param action ACTION_DOWN or ACTION_UP
     * @param keycode Android keycode (e.g., AKEYCODE_HOME = 3)
     * @param repeat Repeat count (0 for normal)
     */
    fun buildKeyPacket(
        action: Int,
        keycode: Int,
        repeat: Int = 0
    ): ByteArray {
        val buf = ByteBuffer.allocate(14).order(ByteOrder.BIG_ENDIAN)
        buf.put(TYPE_INJECT_KEY.toByte())
        buf.put(action.toByte())
        buf.putInt(keycode)
        buf.putInt(repeat)
        buf.putInt(0) // meta state = 0
        return buf.array()
    }

    /**
     * Build a scroll event packet (23 bytes).
     *
     * @param x Scroll position X
     * @param y Scroll position Y
     * @param scrollX Horizontal scroll amount
     * @param scrollY Vertical scroll amount (positive = up, negative = down)
     * @param screenWidth Device screen width
     * @param screenHeight Device screen height
     */
    fun buildScrollPacket(
        x: Int,
        y: Int,
        scrollX: Int,
        scrollY: Int,
        screenWidth: Int,
        screenHeight: Int
    ): ByteArray {
        val buf = ByteBuffer.allocate(23).order(ByteOrder.BIG_ENDIAN)
        buf.put(TYPE_INJECT_SCROLL.toByte())
        buf.putInt(x)
        buf.putInt(y)
        buf.putShort(screenWidth.toShort())
        buf.putShort(screenHeight.toShort())
        buf.putInt(scrollX)
        buf.putInt(scrollY)
        buf.putShort(0) // buttons = 0
        return buf.array()
    }

    /**
     * Build a back or screen on packet (TYPE_BACK_OR_SCREEN_ON = 4).
     */
    fun buildBackOrScreenOn(): ByteArray {
        return byteArrayOf(TYPE_BACK_OR_SCREEN_ON.toByte())
    }

    /**
     * Build an app switch packet (TYPE_APP_SWITCH = 8).
     */
    fun buildAppSwitch(): ByteArray {
        return byteArrayOf(TYPE_APP_SWITCH.toByte())
    }

    /**
     * Build a set screen power mode packet (2 bytes).
     * @param mode 0=OFF, 1=ON, 2=DOZE
     */
    fun buildSetScreenPowerMode(mode: Int): ByteArray {
        val buf = ByteBuffer.allocate(2).order(ByteOrder.BIG_ENDIAN)
        buf.put(TYPE_SET_SCREEN_POWER_MODE.toByte())
        buf.put(mode.toByte())
        return buf.array()
    }

    /**
     * Convenience: build key press (down + up) as two packets.
     */
    fun buildKeyPress(keycode: Int): ByteArray {
        val down = buildKeyPacket(ACTION_DOWN, keycode)
        val up = buildKeyPacket(ACTION_UP, keycode)
        return down + up
    }
}
