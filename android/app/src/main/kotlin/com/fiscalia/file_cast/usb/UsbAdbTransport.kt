package com.fiscalia.file_cast.usb

import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.util.Log
import com.fiscalia.file_cast.adb.AdbAuth
import com.fiscalia.file_cast.adb.AdbMessage
import com.fiscalia.file_cast.adb.AdbProtocol
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock
import kotlin.concurrent.thread

class UsbAdbTransport(
    private val device: UsbDevice,
    private val connection: UsbDeviceConnection,
    private val adbAuth: AdbAuth
) {
    companion object {
        private const val TAG = "UsbAdbTransport"
        private const val ADB_CLASS = 0xFF
        private const val ADB_SUBCLASS = 0x42
        private const val ADB_PROTOCOL = 0x01
        private const val READ_TIMEOUT = 5000
        private const val WRITE_TIMEOUT = 5000
        private const val AUTH_READ_TIMEOUT = 30000
        private const val HANDSHAKE_GLOBAL_TIMEOUT = 40000L

        fun logDeviceInfo(device: UsbDevice): String {
            val sb = StringBuilder()
            sb.appendLine("=== DEVICE INFO ===")
            sb.appendLine("Name: ${device.deviceName}")
            sb.appendLine("Product: ${device.productName}")
            sb.appendLine("Manufacturer: ${device.manufacturerName}")
            sb.appendLine("VID: 0x${Integer.toHexString(device.vendorId)}")
            sb.appendLine("PID: 0x${Integer.toHexString(device.productId)}")
            sb.appendLine("Class: ${device.deviceClass}")
            sb.appendLine("Subclass: ${device.deviceSubclass}")
            sb.appendLine("Protocol: ${device.deviceProtocol}")
            sb.appendLine("Interfaces: ${device.interfaceCount}")
            for (i in 0 until device.interfaceCount) {
                val iface = device.getInterface(i)
                sb.appendLine("  IF$i: class=${iface.interfaceClass} sub=${iface.interfaceSubclass} proto=${iface.interfaceProtocol} name=${iface.name} endpoints=${iface.endpointCount}")
                for (j in 0 until iface.endpointCount) {
                    val ep = iface.getEndpoint(j)
                    sb.appendLine("    EP$j: addr=0x${Integer.toHexString(ep.address)} dir=${if (ep.direction == 128) "IN" else "OUT"} type=${ep.type} maxPkt=${ep.maxPacketSize}")
                }
            }
            sb.appendLine("===================")
            Log.d(TAG, sb.toString())
            return sb.toString()
        }
    }

    private var readEndpoint: UsbEndpoint? = null
    private var writeEndpoint: UsbEndpoint? = null
    private var interface_: UsbInterface? = null

    private val localIdCounter = AtomicInteger(1)
    private val streams = ConcurrentHashMap<Int, AdbStream>()
    private val writeLock = ReentrantLock()
    private val readLock = ReentrantLock()
    private var isConnected = false
    private val disconnected = AtomicBoolean(false)

    private var onStateChanged: ((String, String?, String) -> Unit)? = null

    // Log buffer - all messages sent to UI
    private val logBuffer = StringBuilder()

    private fun log(msg: String) {
        val line = "[${System.currentTimeMillis() % 100000}] $msg"
        logBuffer.appendLine(line)
        Log.d(TAG, msg)
    }

    private fun getLog(): String = logBuffer.toString()

    fun findAdbInterface(): Boolean {
        log("=== findAdbInterface ===")
        log("Device: ${device.deviceName}, Interfaces: ${device.interfaceCount}")

        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            log("IF$i: class=${iface.interfaceClass} sub=${iface.interfaceSubclass} proto=${iface.interfaceProtocol} name=${iface.name}")
        }

        // Exact ADB interface match
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            if (iface.interfaceClass == ADB_CLASS &&
                iface.interfaceSubclass == ADB_SUBCLASS &&
                iface.interfaceProtocol == ADB_PROTOCOL) {
                log("Found ADB interface at index $i")
                return claimInterface(iface)
            }
        }

        // Fallback: vendor-specific class
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            if (iface.interfaceClass == ADB_CLASS) {
                log("Found vendor class=0xFF at index $i")
                return claimInterface(iface)
            }
        }

        // Last resort: first interface
        if (device.interfaceCount > 0) {
            log("WARNING: Using first interface as fallback")
            return claimInterface(device.getInterface(0))
        }

        log("ERROR: No interfaces found!")
        return false
    }

    private fun claimInterface(iface: UsbInterface): Boolean {
        log("=== claimInterface: ${iface.name} ===")

        val claimed = connection.claimInterface(iface, true)
        log("claimInterface force=true result: $claimed")
        if (!claimed) {
            log("ERROR: Failed to claim interface")
            return false
        }

        interface_ = iface

        for (i in 0 until iface.endpointCount) {
            val endpoint = iface.getEndpoint(i)
            val dir = if (endpoint.direction == 128) "IN" else "OUT"
            val type = when (endpoint.type) {
                0 -> "CTRL"
                1 -> "ISO"
                2 -> "BULK"
                3 -> "INT"
                else -> "?${endpoint.type}"
            }
            log("EP$i: addr=0x${Integer.toHexString(endpoint.address)} dir=$dir type=$type maxPkt=${endpoint.maxPacketSize}")
            if (endpoint.type == 2) {
                if (endpoint.direction == 128) {
                    readEndpoint = endpoint
                    log("  -> READ endpoint: 0x${Integer.toHexString(endpoint.address)}")
                } else if (endpoint.direction == 0) {
                    writeEndpoint = endpoint
                    log("  -> WRITE endpoint: 0x${Integer.toHexString(endpoint.address)}")
                }
            }
        }

        if (readEndpoint == null || writeEndpoint == null) {
            log("ERROR: No bulk endpoints found! read=$readEndpoint write=$writeEndpoint")
            releaseInterface()
            return false
        }

        log("Interface claimed OK. READ=0x${Integer.toHexString(readEndpoint!!.address)} WRITE=0x${Integer.toHexString(writeEndpoint!!.address)}")
        return true
    }

    fun releaseInterface() {
        interface_?.let { connection.releaseInterface(it) }
        interface_ = null
        readEndpoint = null
        writeEndpoint = null
    }

    fun handshake(): Boolean {
        logBuffer.clear()
        log("=== HANDSHAKE START ===")
        disconnected.set(false)

        if (readEndpoint == null || writeEndpoint == null) {
            log("ERROR: Endpoints not initialized!")
            notifyState("error", "Endpoints no inicializados", getLog())
            return false
        }

        val startTime = System.currentTimeMillis()

        try {
            notifyState("connecting", null, getLog())

            log("Initializing RSA keys...")
            adbAuth.init()
            val fp = adbAuth.getKeyFingerprint()
            log("RSA fingerprint: ${fp ?: "null"}")

            val cnxnPacket = AdbProtocol.buildCnxn()
            log("CNXN packet: ${cnxnPacket.size} bytes total")
            log("CNXN header (24B): ${cnxnPacket.sliceArray(0 until minOf(24, cnxnPacket.size)).joinToString(" ") { "%02X".format(it) }}")
            if (cnxnPacket.size > 24) {
                log("CNXN payload: ${cnxnPacket.sliceArray(24 until cnxnPacket.size).joinToString(" ") { "%02X".format(it) }}")
                log("CNXN payload str: ${String(cnxnPacket, 24, cnxnPacket.size - 24).trimEnd('\u0000')}")
            }

            log("Sending CNXN via USB bulk transfer...")
            val sendResult = sendRaw(cnxnPacket)
            val elapsed = System.currentTimeMillis() - startTime
            log("CNXN send result: $sendResult (${elapsed}ms)")

            if (!sendResult) {
                log("FAILED to send CNXN!")
                log("Possible causes:")
                log("  - USB cable may not support data")
                log("  - Wrong USB endpoint")
                log("  - Device not ready")
                notifyState("error", "No se pudo enviar CNXN. Verifica cable y Depuracion USB.", getLog())
                return false
            }

            if (disconnected.get()) {
                log("Device disconnected during handshake")
                notifyState("error", "Dispositivo desconectado", getLog())
                return false
            }

            log("Waiting for device response (timeout ${READ_TIMEOUT}ms)...")
            val response = readMessage()
            val elapsed2 = System.currentTimeMillis() - startTime

            if (response == null) {
                log("NO RESPONSE from device after ${elapsed2}ms")
                log("")
                log("=== POSSIBLE CAUSES ===")
                log("1. Depuracion USB no activada en el dispositivo objetivo")
                log("2. Cable USB sin soporte de datos (solo carga)")
                log("3. Dispositivo bloqueado (pantalla apagada)")
                log("4. ADB daemon no disponible en este puerto USB")
                log("5. Samsung: intenta cambiar modo USB a 'Transferencia de archivos'")
                log("========================")
                notifyState("error", "El dispositivo no responde. Revisa Depuracion USB.", getLog())
                return false
            }

            log("Response received: ${response.commandName} arg0=${response.arg0} arg1=${response.arg1} dataLen=${response.dataLength}")

            when (response.command) {
                AdbProtocol.A_AUTH -> {
                    log("Device sent AUTH (type=${response.authTypeName})")
                    return handleAuth(response, startTime, signatureAttempted = false)
                }
                AdbProtocol.A_CNXN -> {
                    log("Device sent CNXN - already authorized!")
                    isConnected = true
                    notifyState("connected", null, getLog())
                    return true
                }
                else -> {
                    log("Unexpected command: ${response.commandName}")
                    notifyState("error", "Comando inesperado: ${response.commandName}", getLog())
                    return false
                }
            }
        } catch (t: Throwable) {
            val elapsed = System.currentTimeMillis() - startTime
            log("EXCEPTION after ${elapsed}ms: ${t.javaClass.simpleName}: ${t.message}")
            log("Stack: ${t.stackTraceToString()}")
            notifyState("error", "Excepcion: ${t.message}", getLog())
            return false
        }
    }

    private fun handleAuth(authMessage: AdbMessage, startTime: Long, signatureAttempted: Boolean = false): Boolean {
        log("handleAuth type=${authMessage.authTypeName} arg0=${authMessage.arg0} signatureAttempted=$signatureAttempted")

        when (authMessage.arg0) {
            AdbProtocol.ADB_AUTH_TOKEN -> {
                log("Reading AUTH TOKEN payload (${authMessage.dataLength} bytes)...")
                val token = readPayload(authMessage.dataLength)
                if (token == null) {
                    log("ERROR: Failed to read token payload")
                    notifyState("error", "No se pudo leer token de autenticacion", getLog())
                    return false
                }

                log("Token: ${token.size} bytes")
                log("Token hex: ${token.joinToString(" ") { "%02X".format(it) }}")

                // If we already tried signing and device sent ANOTHER TOKEN,
                // it means our signature was rejected (key not authorized yet).
                // Send the public key so the RSA dialog appears.
                if (signatureAttempted) {
                    log("Signature already rejected once -> sending public key for dialog")
                    return sendPublicKey(startTime)
                }

                val signature = adbAuth.signToken(token)
                if (signature == null) {
                    log("WARNING: signToken returned null, sending public key...")
                    return sendPublicKey(startTime)
                }

                log("Signature: ${signature.size} bytes")
                val authPacket = AdbProtocol.buildAuthSignature(signature)
                log("Sending AUTH_SIGNATURE (${authPacket.size} bytes)...")
                val sendResult = sendRaw(authPacket)
                log("AUTH_SIGNATURE send result: $sendResult")

                if (!sendResult) {
                    log("Failed to send signature, trying public key...")
                    return sendPublicKey(startTime)
                }

                log("Waiting for auth response...")
                val nextMessage = readMessage()
                val elapsed = System.currentTimeMillis() - startTime

                if (nextMessage == null) {
                    log("NO RESPONSE after AUTH_SIGNATURE after ${elapsed}ms")
                    notifyState("error", "Sin respuesta despues de firma. Revisa el dispositivo.", getLog())
                    return false
                }

                log("Auth response: ${nextMessage.commandName}")

                // If another AUTH comes back, it's the expected rejection.
                // Re-enter with signatureAttempted=true so next time we send public key.
                return if (nextMessage.command == AdbProtocol.A_AUTH) {
                    handleAuth(nextMessage, startTime, signatureAttempted = true)
                } else {
                    handleAuthResponse(nextMessage, startTime)
                }
            }
            AdbProtocol.ADB_AUTH_SIGNATURE -> {
                log("ERROR: Unexpected SIGNATURE from device")
                notifyState("error", "Firma inesperada del dispositivo", getLog())
                return false
            }
            AdbProtocol.ADB_AUTH_RSAPUBLICKEY -> {
                log("ERROR: Unexpected PUBLIC KEY from device")
                notifyState("error", "Clave inesperada del dispositivo", getLog())
                return false
            }
            else -> {
                log("ERROR: Unknown auth type: ${authMessage.arg0}")
                notifyState("error", "Tipo auth desconocido: ${authMessage.arg0}", getLog())
                return false
            }
        }
    }

    private fun handleAuthResponse(nextMessage: AdbMessage, startTime: Long): Boolean {
        return when (nextMessage.command) {
            AdbProtocol.A_AUTH -> {
                log("Another AUTH request, handling with signatureAttempted=true...")
                handleAuth(nextMessage, startTime, signatureAttempted = true)
            }
            AdbProtocol.A_CNXN -> {
                log("CNXN received - CONNECTED!")
                isConnected = true
                notifyState("connected", null, getLog())
                true
            }
            else -> {
                log("Unexpected command after auth: ${nextMessage.commandName}")
                notifyState("error", "Respuesta inesperada: ${nextMessage.commandName}", getLog())
                false
            }
        }
    }

    private fun sendPublicKey(startTime: Long): Boolean {
        // The AUTH_RSAPUBLICKEY wire payload must be base64-encoded android_pubkey struct.
        // Device does "PK" + key_data and base64-decodes to get the struct.
        val publicKeyBase64 = adbAuth.getAndroidPublicKeyBase64()
        if (publicKeyBase64 == null) {
            log("ERROR: Failed to get public key")
            notifyState("error", "No se pudo generar clave publica RSA", getLog())
            return false
        }

        log("Public key base64: ${publicKeyBase64.length} chars")
        log("Public key header: ${publicKeyBase64.substring(0, minOf(7, publicKeyBase64.length))}")

        val keyBytes = publicKeyBase64.toByteArray(Charsets.US_ASCII)
        val authPacket = AdbProtocol.buildAuthPublicKey(keyBytes)
        log("Sending AUTH_RSAPUBLICKEY (${authPacket.size} bytes, payload ${keyBytes.size} bytes)...")
        val sendResult = sendRaw(authPacket)
        log("AUTH_RSAPUBLICKEY send result: $sendResult")

        if (!sendResult) {
            log("ERROR: Failed to send public key")
            notifyState("error", "No se pudo enviar clave publica", getLog())
            return false
        }

        notifyState("authorizing", "Acepta la solicitud en el dispositivo objetivo", getLog())

        // Start watchdog: if Samsung re-enumerates USB, bulkTransfer may hang forever.
        // Force-close the connection after AUTH_READ_TIMEOUT + margin to unblock it.
        val readLatch = CountDownLatch(1)
        val watchdogMargin = 8000L
        val watchdog = thread(name = "auth-watchdog", isDaemon = true) {
            try {
                val totalWait = AUTH_READ_TIMEOUT.toLong() + watchdogMargin
                log("Watchdog: waiting ${totalWait}ms for read to complete...")
                val completed = readLatch.await(totalWait, TimeUnit.MILLISECONDS)
                if (!completed) {
                    log("Watchdog: TIMEOUT - forcing connection close to unblock bulkTransfer")
                    log("Watchdog: This likely means Samsung re-enumerated USB after dialog acceptance")
                    try {
                        connection.close()
                    } catch (e: Exception) {
                        log("Watchdog: close() exception: ${e.message}")
                    }
                } else {
                    log("Watchdog: read completed normally, no force-close needed")
                }
            } catch (e: InterruptedException) {
                log("Watchdog: interrupted")
            }
        }

        try {
            log("Waiting for response after public key (timeout ${AUTH_READ_TIMEOUT}ms)...")
            val nextMessage = readMessage(AUTH_READ_TIMEOUT)
            val elapsed = System.currentTimeMillis() - startTime

            if (nextMessage == null) {
                log("NO RESPONSE after public key after ${elapsed}ms")
                log("The RSA dialog should have appeared on the target device.")
                log("If not visible:")
                log("  1. Check screen for dialog")
                log("  2. Try 'Revoke USB debugging authorizations'")
                log("  3. Restart ADB on target")
                log("  4. Try different USB cable")
                log("  5. Samsung: try USB mode 'Transfer files' then back")
                notifyState("error", "Sin respuesta. Dialog RSA deberia visible en dispositivo.", getLog())
                return false
            }

            log("Response after public key: ${nextMessage.commandName}")
            return handleAuthResponse(nextMessage, startTime)
        } finally {
            readLatch.countDown() // signal watchdog that read finished
            watchdog.join(2000)  // wait for watchdog to exit
        }
    }

    fun sendRaw(data: ByteArray): Boolean {
        writeLock.withLock {
            if (disconnected.get()) {
                log("ERROR: Device disconnected, aborting write")
                return false
            }
            val endpoint = writeEndpoint ?: run {
                log("ERROR: writeEndpoint is null!")
                return false
            }
            val fd = connection.fileDescriptor
            log("USB WRITE: ${data.size} bytes to EP 0x${Integer.toHexString(endpoint.address)} fd=$fd")
            val bytesWritten = connection.bulkTransfer(
                endpoint,
                data,
                data.size,
                WRITE_TIMEOUT
            )
            log("USB WRITE result: $bytesWritten bytes (timeout=${WRITE_TIMEOUT}ms)")
            if (bytesWritten < 0) {
                log("USB WRITE FAILED: bulkTransfer returned -1")
                log("Connection fd=$fd, active=${connection.bulkTransfer(writeEndpoint, ByteArray(0), 0, 100)}")
                return false
            }
            return true
        }
    }

    fun readRaw(buffer: ByteArray, timeoutMs: Int = READ_TIMEOUT): Int {
        readLock.withLock {
            if (disconnected.get()) {
                log("ERROR: Device disconnected, aborting read")
                return -1
            }
            val endpoint = readEndpoint ?: run {
                log("ERROR: readEndpoint is null!")
                return -1
            }
            log("USB READ: waiting ${buffer.size} bytes from EP 0x${Integer.toHexString(endpoint.address)} timeout=${timeoutMs}ms")
            val bytesRead = connection.bulkTransfer(
                endpoint,
                buffer,
                buffer.size,
                timeoutMs
            )
            log("USB READ result: $bytesRead bytes")
            if (bytesRead > 0) {
                log("USB READ data: ${buffer.sliceArray(0 until minOf(bytesRead, 48)).joinToString(" ") { "%02X".format(it) }}")
            } else if (bytesRead == 0) {
                log("USB READ: got 0 bytes (device empty)")
            } else {
                log("USB READ: returned -1 (timeout or error)")
            }
            return bytesRead
        }
    }

    fun readMessage(timeoutMs: Int = READ_TIMEOUT): AdbMessage? {
        log("readMessage: reading ${AdbProtocol.HEADER_SIZE} byte header (timeout=${timeoutMs}ms)...")
        val headerBuffer = ByteArray(AdbProtocol.HEADER_SIZE)
        val bytesRead = readRaw(headerBuffer, timeoutMs)

        if (bytesRead == 0) {
            log("readMessage: 0 bytes - device not responding")
            return null
        }
        if (bytesRead < 0) {
            log("readMessage: $bytesRead - timeout or read error")
            return null
        }
        if (bytesRead != AdbProtocol.HEADER_SIZE) {
            log("readMessage: incomplete header: ${bytesRead}/${AdbProtocol.HEADER_SIZE} bytes")
            log("readMessage: partial hex: ${headerBuffer.sliceArray(0 until bytesRead).joinToString(" ") { "%02X".format(it) }}")
            return null
        }

        log("readMessage: header hex: ${headerBuffer.joinToString(" ") { "%02X".format(it) }}")
        val message = AdbProtocol.parseHeader(headerBuffer)
        if (message == null) {
            val cmd = java.nio.ByteBuffer.wrap(headerBuffer.sliceArray(0..3)).order(java.nio.ByteOrder.LITTLE_ENDIAN).int
            log("readMessage: INVALID MAGIC! cmd=0x${Integer.toHexString(cmd)} expected_xor=0x${Integer.toHexString(cmd xor 0xffffffff.toInt())}")
            log("readMessage: raw bytes: ${headerBuffer.joinToString(" ") { "%02X".format(it) }}")
        } else {
            log("readMessage: OK ${message.commandName} arg0=${message.arg0} arg1=${message.arg1} dataLen=${message.dataLength} dataCheck=0x${Integer.toHexString(message.dataCheck)}")
        }
        return message
    }

    fun readPayload(length: Int): ByteArray? {
        if (length == 0) return null
        log("readPayload: reading $length bytes...")
        val payload = ByteArray(length)
        var totalRead = 0

        while (totalRead < length) {
            val remaining = length - totalRead
            val tempBuffer = ByteArray(remaining)
            val bytesRead = readRaw(tempBuffer)

            if (bytesRead < 0) {
                log("readPayload: FAILED at $totalRead/$length bytes")
                return null
            }
            if (bytesRead == 0) {
                log("readPayload: got 0 bytes at $totalRead/$length")
                return null
            }

            System.arraycopy(tempBuffer, 0, payload, totalRead, bytesRead)
            totalRead += bytesRead
        }

        log("readPayload: complete ${payload.size} bytes")
        return payload
    }

    fun disconnect() {
        disconnected.set(true)
        isConnected = false
        streams.clear()
        releaseInterface()
        notifyState("disconnected", null, getLog())
    }

    fun setOnStateChangedListener(listener: (String, String?, String) -> Unit) {
        onStateChanged = listener
    }

    private fun notifyState(state: String, message: String?, log: String) {
        log("notifyState: $state - $message")
        onStateChanged?.invoke(state, message, log)
    }

    fun isAdbConnected(): Boolean = isConnected
}

data class AdbStream(
    val localId: Int,
    var remoteId: Int? = null,
    val dataQueue: ConcurrentLinkedQueue<ByteArray> = ConcurrentLinkedQueue()
)
