package com.fiscalia.file_cast.adb

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32

/**
 * ADB Protocol constants and packet building.
 * Based on AOSP protocol.txt and OVERVIEW.TXT.
 */
object AdbProtocol {

    // ADB Commands (magic numbers)
    const val A_CNXN = 0x4e584e43  // Connect
    const val A_OPEN = 0x4e45504f  // Open stream
    const val A_OKAY = 0x59414b4f  // Ready/Acknowledge
    const val A_CLSE = 0x45534c43  // Close stream
    const val A_WRTE = 0x45545257  // Write data
    const val A_AUTH = 0x48545541  // Authenticate
    const val A_STLS = 0x534c5453  // Start TLS

    // Auth types
    const val ADB_AUTH_TOKEN = 1
    const val ADB_AUTH_SIGNATURE = 2
    const val ADB_AUTH_RSAPUBLICKEY = 3

    // Protocol version
    const val A_VERSION = 0x01000000
    const val A_VERSION_SKIP_CHECKSUM = 0x01000001

    // Max payload size
    const val MAX_PAYLOAD = 4 * 1024 * 1024  // 4 MB
    const val ADB_USB_MAX_PAYLOAD = 16 * 1024 // 16 KB for USB

    // Message header size
    const val HEADER_SIZE = 24

    /**
     * Build an ADB message header.
     */
    fun buildMessage(
        command: Int,
        arg0: Int = 0,
        arg1: Int = 0,
        payload: ByteArray? = null
    ): ByteArray {
        val dataLength = payload?.size ?: 0
        val dataCheck = if (payload != null) calculateChecksum(payload) else 0
        val magic = command xor 0xffffffff.toInt()

        val buffer = ByteBuffer.allocate(HEADER_SIZE).apply {
            order(ByteOrder.LITTLE_ENDIAN)
            putInt(command)
            putInt(arg0)
            putInt(arg1)
            putInt(dataLength)
            putInt(dataCheck)
            putInt(magic)
        }
        return buffer.array()
    }

    /**
     * Build a complete ADB packet (header + payload).
     */
    fun buildPacket(
        command: Int,
        arg0: Int = 0,
        arg1: Int = 0,
        payload: ByteArray? = null
    ): ByteArray {
        val header = buildMessage(command, arg0, arg1, payload)
        return if (payload != null) {
            header + payload
        } else {
            header
        }
    }

    /**
     * Parse an ADB message header from bytes.
     */
    fun parseHeader(data: ByteArray): AdbMessage? {
        if (data.size < HEADER_SIZE) return null

        val buffer = ByteBuffer.wrap(data).apply {
            order(ByteOrder.LITTLE_ENDIAN)
        }

        val command = buffer.getInt()
        val arg0 = buffer.getInt()
        val arg1 = buffer.getInt()
        val dataLength = buffer.getInt()
        val dataCheck = buffer.getInt()
        val magic = buffer.getInt()

        // Verify magic
        if (command xor magic != 0xffffffff.toInt()) {
            return null
        }

        return AdbMessage(
            command = command,
            arg0 = arg0,
            arg1 = arg1,
            dataLength = dataLength,
            dataCheck = dataCheck,
            magic = magic
        )
    }

    /**
     * Calculate CRC32 checksum of data.
     */
    fun calculateChecksum(data: ByteArray): Int {
        val crc = CRC32()
        crc.update(data)
        return crc.value.toInt()
    }

    /**
     * Build CNXN (Connect) packet.
     * Host sends CNXN with version, maxdata, and system identity string.
     * For USB, maxPayload should be ADB_USB_MAX_PAYLOAD (16KB).
     * Identity must be "host::" per ADB protocol.
     */
    fun buildCnxn(version: Int = A_VERSION, maxPayload: Int = ADB_USB_MAX_PAYLOAD): ByteArray {
        val identity = "host::"
        val payload = identity.toByteArray() + 0.toByte() // null-terminated
        return buildPacket(A_CNXN, version, maxPayload, payload)
    }

    /**
     * Build AUTH packet with signature.
     */
    fun buildAuthSignature(signature: ByteArray): ByteArray {
        return buildPacket(A_AUTH, ADB_AUTH_SIGNATURE, 0, signature)
    }

    /**
     * Build AUTH packet with public key.
     */
    fun buildAuthPublicKey(publicKey: ByteArray): ByteArray {
        return buildPacket(A_AUTH, ADB_AUTH_RSAPUBLICKEY, 0, publicKey)
    }

    /**
     * Build OPEN packet to open a stream.
     */
    fun buildOpen(localId: Int, service: String): ByteArray {
        val payload = service.toByteArray() + 0.toByte() // null-terminated
        return buildPacket(A_OPEN, localId, 0, payload)
    }

    /**
     * Build OKAY packet.
     */
    fun buildOkay(localId: Int, remoteId: Int): ByteArray {
        return buildPacket(A_OKAY, localId, remoteId)
    }

    /**
     * Build WRITE packet.
     */
    fun buildWrite(localId: Int, remoteId: Int, data: ByteArray): ByteArray {
        return buildPacket(A_WRTE, localId, remoteId, data)
    }

    /**
     * Build CLOSE packet.
     */
    fun buildClose(localId: Int, remoteId: Int): ByteArray {
        return buildPacket(A_CLSE, localId, remoteId)
    }
}

/**
 * Parsed ADB message.
 */
data class AdbMessage(
    val command: Int,
    val arg0: Int,
    val arg1: Int,
    val dataLength: Int,
    val dataCheck: Int,
    val magic: Int
) {
    val commandName: String
        get() = when (command) {
            AdbProtocol.A_CNXN -> "CNXN"
            AdbProtocol.A_AUTH -> "AUTH"
            AdbProtocol.A_OPEN -> "OPEN"
            AdbProtocol.A_OKAY -> "OKAY"
            AdbProtocol.A_CLSE -> "CLSE"
            AdbProtocol.A_WRTE -> "WRTE"
            AdbProtocol.A_STLS -> "STLS"
            else -> "UNKNOWN(0x${Integer.toHexString(command)})"
        }

    val authTypeName: String
        get() = when (arg0) {
            AdbProtocol.ADB_AUTH_TOKEN -> "TOKEN"
            AdbProtocol.ADB_AUTH_SIGNATURE -> "SIGNATURE"
            AdbProtocol.ADB_AUTH_RSAPUBLICKEY -> "RSAPUBLICKEY"
            else -> "UNKNOWN($arg0)"
        }
}
