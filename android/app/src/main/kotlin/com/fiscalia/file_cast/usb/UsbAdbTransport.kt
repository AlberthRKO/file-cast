package com.fiscalia.file_cast.usb

import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.util.Log
import com.fiscalia.file_cast.adb.AdbAuth
import com.fiscalia.file_cast.adb.AdbMessage
import com.fiscalia.file_cast.adb.AdbProtocol
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingDeque
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
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

    @Volatile
    var quietMode = false  // suppress logging during active mirror for performance

    private fun log(msg: String) {
        if (quietMode) return
        val line = "[${System.currentTimeMillis() % 100000}] $msg"
        logBuffer.appendLine(line)
        Log.d(TAG, msg)
    }

    fun getLog(): String = logBuffer.toString()

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
                    log("Device sent CNXN - already authorized! dataLen=${response.dataLength}")
                    if (response.dataLength > 0) {
                        val identity = readPayload(response.dataLength)
                        log("CNXN identity: ${identity?.let { String(it, Charsets.UTF_8).trimEnd('\u0000') } ?: "null"}")
                    }
                    isConnected = true
                    startReaderThread()
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
                log("CNXN received - CONNECTED! dataLen=${nextMessage.dataLength}")
                if (nextMessage.dataLength > 0) {
                    val identity = readPayload(nextMessage.dataLength)
                    log("CNXN identity: ${identity?.let { String(it, Charsets.UTF_8).trimEnd('\u0000') } ?: "null"}")
                }
                isConnected = true
                startReaderThread()
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
            if (!quietMode && bytesRead > 0) {
                log("USB READ data: ${buffer.sliceArray(0 until minOf(bytesRead, 48)).joinToString(" ") { "%02X".format(it) }}")
            } else if (bytesRead == 0) {
                log("USB READ: got 0 bytes (device empty)")
            } else if (!quietMode) {
                log("USB READ: returned -1 (timeout or error)")
            }
            return bytesRead
        }
    }

    fun readMessage(timeoutMs: Int = READ_TIMEOUT): AdbMessage? {
        if (!quietMode) log("readMessage: reading ${AdbProtocol.HEADER_SIZE} byte header (timeout=${timeoutMs}ms)...")
        val headerBuffer = ByteArray(AdbProtocol.HEADER_SIZE)
        val bytesRead = readRaw(headerBuffer, timeoutMs)

        if (bytesRead == 0) {
            if (!quietMode) log("readMessage: 0 bytes - device not responding")
            return null
        }
        if (bytesRead < 0) {
            if (!quietMode) log("readMessage: $bytesRead - timeout or read error")
            return null
        }
        if (bytesRead != AdbProtocol.HEADER_SIZE) {
            if (!quietMode) {
                log("readMessage: incomplete header: ${bytesRead}/${AdbProtocol.HEADER_SIZE} bytes")
                log("readMessage: partial hex: ${headerBuffer.sliceArray(0 until bytesRead).joinToString(" ") { "%02X".format(it) }}")
            }
            return null
        }

        if (!quietMode) log("readMessage: header hex: ${headerBuffer.joinToString(" ") { "%02X".format(it) }}")
        val message = AdbProtocol.parseHeader(headerBuffer)
        if (message == null) {
            if (!quietMode) {
                val cmd = java.nio.ByteBuffer.wrap(headerBuffer.sliceArray(0..3)).order(java.nio.ByteOrder.LITTLE_ENDIAN).int
                log("readMessage: INVALID MAGIC! cmd=0x${Integer.toHexString(cmd)} expected_xor=0x${Integer.toHexString(cmd xor 0xffffffff.toInt())}")
                log("readMessage: raw bytes: ${headerBuffer.joinToString(" ") { "%02X".format(it) }}")
            }
        } else {
            if (!quietMode) log("readMessage: OK ${message.commandName} arg0=${message.arg0} arg1=${message.arg1} dataLen=${message.dataLength} dataCheck=0x${Integer.toHexString(message.dataCheck)}")
        }
        return message
    }

    fun readPayload(length: Int): ByteArray? {
        if (length == 0) return null
        if (!quietMode) log("readPayload: reading $length bytes...")
        val payload = ByteArray(length)
        var totalRead = 0

        while (totalRead < length) {
            val remaining = length - totalRead
            val tempBuffer = ByteArray(remaining)
            val bytesRead = readRaw(tempBuffer)

            if (bytesRead < 0) {
                if (!quietMode) log("readPayload: FAILED at $totalRead/$length bytes")
                return null
            }
            if (bytesRead == 0) {
                if (!quietMode) log("readPayload: got 0 bytes at $totalRead/$length")
                return null
            }

            System.arraycopy(tempBuffer, 0, payload, totalRead, bytesRead)
            totalRead += bytesRead
        }

        if (!quietMode) log("readPayload: complete ${payload.size} bytes")
        return payload
    }

    fun disconnect() {
        disconnected.set(true)
        isConnected = false
        readerRunning = false
        stopControlWriter()
        streams.clear()
        releaseInterface()
        notifyState("disconnected", null, getLog())
    }

    // --- Stream multiplexing ---

    private var readerRunning = false
    private var readerThread: Thread? = null

    // Sync sub-protocol constants - raw ASCII bytes, NOT little-endian integers
    private val SYNC_SEND = "SEND".toByteArray(Charsets.US_ASCII)
    private val SYNC_DATA = "DATA".toByteArray(Charsets.US_ASCII)
    private val SYNC_DONE = "DONE".toByteArray(Charsets.US_ASCII)
    private val SYNC_OKAY = "OKAY".toByteArray(Charsets.US_ASCII)
    private val SYNC_FAIL = "FAIL".toByteArray(Charsets.US_ASCII)
    private val REG_FILE = 33188  // 0o100644
    private val PUSH_CHUNK_SIZE = 4096  // smaller chunks, more stable on phone-to-phone OTG

    /**
     * Start the reader thread that demultiplexes incoming ADB packets.
     * Must be called after handshake() returns true.
     */
    fun startReaderThread() {
        if (readerRunning) return
        readerRunning = true
        readerThread = thread(name = "AdbReader", isDaemon = true) {
            log("Reader thread started")
            readerLoop()
            log("Reader thread exiting")
        }
    }

    private fun readerLoop() {
        while (readerRunning && !disconnected.get()) {
            try {
                val message = readMessage(2000) ?: continue
                when (message.command) {
                    AdbProtocol.A_OKAY -> {
                        // Device puts our local_id in arg1, device's remote_id in arg0
                        val stream = streams[message.arg1]
                        if (stream != null) {
                            stream.okayRemoteId = message.arg0
                            stream.okayReceived.countDown()
                            stream.writeOkayQueue.offer(message.arg0)
                            log("OKAY dispatched to stream ${message.arg1} (remoteId=${message.arg0})")
                        } else {
                            log("OKAY for unknown stream arg1=${message.arg1} arg0=${message.arg0}")
                        }
                    }
                    AdbProtocol.A_WRTE -> {
                        // Device puts our local_id in arg1, device's remote_id in arg0
                        val stream = streams[message.arg1]
                        if (stream != null) {
                            val payload = if (message.dataLength > 0) readPayload(message.dataLength) else null
                            if (payload != null) {
                                stream.dataQueue.add(payload)
                                log("WRTE: ${payload.size} bytes queued for stream ${message.arg1}")
                            }
                            // Send OKAY to acknowledge receipt (flow control)
                            val okayPacket = AdbProtocol.buildOkay(message.arg1, message.arg0)
                            if (!sendRaw(okayPacket)) {
                                log("ERROR: Failed to send OKAY for WRTE")
                            }
                        } else {
                            log("WRTE for unknown stream arg1=${message.arg1}, discarding")
                            if (message.dataLength > 0) readPayload(message.dataLength)
                        }
                    }
                    AdbProtocol.A_CLSE -> {
                        // Device puts our local_id in arg1
                        val stream = streams[message.arg1]
                        if (stream != null) {
                            stream.closed.set(true)
                            stream.closeReceived.countDown()
                            streams.remove(message.arg1)
                            log("CLSE: stream ${message.arg1} closed by device")
                        } else {
                            log("CLSE for unknown stream arg1=${message.arg1}")
                        }
                    }
                    AdbProtocol.A_CNXN -> {
                        log("Unexpected CNXN in reader loop (ignoring)")
                    }
                    AdbProtocol.A_AUTH -> {
                        log("Unexpected AUTH in reader loop (ignoring)")
                    }
                    else -> {
                        log("Unknown command in reader: ${message.commandName} (0x${Integer.toHexString(message.command)})")
                    }
                }
            } catch (e: InterruptedException) {
                log("Reader thread interrupted")
                break
            } catch (e: Exception) {
                log("Reader loop error: ${e.javaClass.simpleName}: ${e.message}")
                if (!disconnected.get()) {
                    Thread.sleep(100)
                }
            }
        }
    }

    /**
     * Open an ADB stream (send A_OPEN, wait for A_OKAY).
     * The returned stream can be used to read data from the device.
     */
    fun openStream(service: String, timeoutMs: Long = 10000): AdbStream {
        val localId = localIdCounter.getAndIncrement()
        val stream = AdbStream(localId)
        streams[localId] = stream
        log("openStream: service='$service' localId=$localId")

        // Send A_OPEN
        val openPacket = AdbProtocol.buildOpen(localId, service)
        if (!sendRaw(openPacket)) {
            streams.remove(localId)
            throw IOException("Failed to send A_OPEN for '$service'")
        }

        // Wait for A_OKAY from device
        val completed = stream.okayReceived.await(timeoutMs, TimeUnit.MILLISECONDS)
        if (!completed) {
            streams.remove(localId)
            throw TimeoutException("Timeout waiting for A_OKAY after A_OPEN for '$service'")
        }

        stream.remoteId = stream.okayRemoteId
        log("openStream: stream $localId opened (remoteId=${stream.remoteId})")
        return stream
    }

    /**
     * Write data to an open stream (send A_WRTE).
     */
    fun writeStream(localId: Int, data: ByteArray, waitForOkay: Boolean = true, timeoutMs: Long = 10000): Boolean {
        val stream = streams[localId] ?: throw IllegalArgumentException("No stream with localId=$localId")
        val remoteId = stream.remoteId ?: throw IllegalStateException("Stream $localId has no remoteId yet")
        log("writeStream: localId=$localId remoteId=$remoteId data=${data.size} bytes")

        val writePacket = AdbProtocol.buildWrite(localId, remoteId, data)
        if (!sendRaw(writePacket)) {
            throw IOException("Failed to send A_WRTE for stream $localId")
        }

        if (!waitForOkay) return true

        val okay = stream.writeOkayQueue.poll(timeoutMs, TimeUnit.MILLISECONDS)
        if (okay == null) {
            log("writeStream: TIMEOUT waiting for A_OKAY on stream $localId")
            throw TimeoutException("Timeout waiting for A_OKAY after A_WRTE on stream $localId")
        }
        return true
    }

    /**
     * Close an ADB stream (send A_CLSE).
     */
    fun closeStream(localId: Int) {
        val stream = streams[localId] ?: return
        val remoteId = stream.remoteId ?: return
        log("closeStream: localId=$localId remoteId=$remoteId")

        stream.closed.set(true)
        val closePacket = AdbProtocol.buildClose(localId, remoteId)
        sendRaw(closePacket)
        streams.remove(localId)
    }

    /**
     * Execute a shell command and return the output.
     * Convenience method: opens stream, reads all output, closes stream.
     */
    fun shellCommand(command: String, timeoutMs: Long = 15000): String {
        log("shellCommand: '$command'")
        val stream = openStream("shell:$command")
        val output = StringBuilder()
        val deadline = System.currentTimeMillis() + timeoutMs

        try {
            while (!stream.closed.get() || stream.dataQueue.isNotEmpty()) {
                val data = stream.dataQueue.poll(500, TimeUnit.MILLISECONDS)
                if (data != null) {
                    output.append(String(data, Charsets.UTF_8))
                } else if (System.currentTimeMillis() > deadline) {
                    log("shellCommand: timeout after ${timeoutMs}ms")
                    break
                }
            }
        } finally {
            closeStream(stream.localId)
        }

        val result = output.toString()
        log("shellCommand: result ${result.length} chars")
        return result
    }

    /**
     * Start a long-running shell process (e.g. scrcpy-server) by opening a shell stream
     * that stays open. The caller MUST call closeStream() when done.
     * Returns the localId of the stream (keeps the process alive).
     */
    fun startPersistentShell(command: String, timeoutMs: Long = 10000): Int {
        log("startPersistentShell: '$command'")
        val stream = openStream("shell:$command", timeoutMs)
        log("startPersistentShell: stream ${stream.localId} opened, process kept alive")
        return stream.localId
    }

    /**
     * Read data from a stream (blocking, with timeout).
     */
    fun readStream(localId: Int, timeoutMs: Long = 5000): ByteArray? {
        val stream = streams[localId] ?: return null
        return stream.dataQueue.poll(timeoutMs, TimeUnit.MILLISECONDS)
    }

    /**
     * Check if a stream is still open.
     */
    fun isStreamOpen(localId: Int): Boolean {
        val stream = streams[localId] ?: return false
        return !stream.closed.get()
    }

    /**
     * Push a file to the device using the ADB sync protocol.
     * Retries up to maxRetries times on failure.
     */
    fun pushFile(localPath: String, remotePath: String, timeoutMs: Long = 30000, maxRetries: Int = 2): Boolean {
        var lastError: Exception? = null
        repeat(maxRetries + 1) { attempt ->
            try {
                if (attempt > 0) {
                    log("pushFile: retry attempt $attempt/$maxRetries")
                    Thread.sleep(500)
                }
                return pushFileOnce(localPath, remotePath, timeoutMs)
            } catch (e: Exception) {
                lastError = e
                log("pushFile: attempt $attempt failed: ${e.message}")
            }
        }
        throw lastError ?: IOException("pushFile failed after $maxRetries retries")
    }

    private fun pushFileOnce(localPath: String, remotePath: String, timeoutMs: Long = 30000): Boolean {
        log("pushFile: '$localPath' -> '$remotePath'")

        val file = java.io.File(localPath)
        if (!file.exists()) {
            throw java.io.FileNotFoundException("File not found: $localPath")
        }
        val fileData = file.readBytes()
        log("pushFile: ${fileData.size} bytes to push")

        val stream = openStream("sync:")
        try {
            // 1. SEND command: "SEND" + len(path,mode) + "path,mode" (comma-separated string)
            val pathAndMode = "$remotePath,$REG_FILE"
            val pathModeBytes = pathAndMode.toByteArray(Charsets.UTF_8)
            val sendPayload = ByteArray(4 + 4 + pathModeBytes.size)
            System.arraycopy(SYNC_SEND, 0, sendPayload, 0, 4)
            java.nio.ByteBuffer.wrap(sendPayload, 4, 4).order(java.nio.ByteOrder.LITTLE_ENDIAN).putInt(pathModeBytes.size)
            System.arraycopy(pathModeBytes, 0, sendPayload, 8, pathModeBytes.size)
            writeStream(stream.localId, sendPayload)
            log("pushFile: SEND sent for '$pathAndMode' (${sendPayload.size} bytes)")

            // 2. DATA chunks
            var offset = 0
            while (offset < fileData.size) {
                // Defensive check: if device already sent FAIL, stop sending
                val early = stream.dataQueue.peek()
                if (early != null && early.size >= 4 && early.sliceArray(0..3).contentEquals(SYNC_FAIL)) {
                    val errMsg = if (early.size > 4) String(early, 4, early.size - 4, Charsets.UTF_8) else "unknown"
                    log("pushFile: FAIL detected mid-transfer - $errMsg")
                    throw IOException("Sync FAIL: $errMsg")
                }

                val chunkSize = minOf(PUSH_CHUNK_SIZE, fileData.size - offset)
                val chunk = fileData.copyOfRange(offset, offset + chunkSize)

                val dataPayload = ByteArray(4 + 4 + chunkSize)
                System.arraycopy(SYNC_DATA, 0, dataPayload, 0, 4)
                java.nio.ByteBuffer.wrap(dataPayload, 4, 4).order(java.nio.ByteOrder.LITTLE_ENDIAN).putInt(chunkSize)
                System.arraycopy(chunk, 0, dataPayload, 8, chunkSize)
                writeStream(stream.localId, dataPayload)
                offset += chunkSize
                log("pushFile: DATA ${offset}/${fileData.size} bytes")
                Thread.sleep(25)
            }

            // 3. DONE command
            val donePayload = ByteArray(8)
            System.arraycopy(SYNC_DONE, 0, donePayload, 0, 4)
            // timestamp = 0 (4 bytes of zeros)
            writeStream(stream.localId, donePayload)
            log("pushFile: DONE sent")

            // 4. Read sync response (OKAY or FAIL)
            val response = readSyncResponse(stream, timeoutMs)
            if (response == null) {
                log("pushFile: no sync response received")
                return false
            }

            val respCmd = response.sliceArray(0 until minOf(4, response.size))
            if (respCmd.contentEquals(SYNC_OKAY)) {
                log("pushFile: SUCCESS - file pushed to '$remotePath'")
                return true
            } else if (respCmd.contentEquals(SYNC_FAIL)) {
                val errMsg = if (response.size > 4) String(response, 4, response.size - 4, Charsets.UTF_8) else "unknown"
                log("pushFile: FAIL - $errMsg")
                throw IOException("Sync FAIL: $errMsg")
            } else {
                log("pushFile: unexpected response: ${response.joinToString(" ") { "%02X".format(it) }}")
                return false
            }
        } finally {
            closeStream(stream.localId)
        }
    }

    /**
     * Read a sync-level response (OKAY/FAIL) from a sync stream.
     * Sync responses come as payloads in A_WRTE packets, queued by the reader thread.
     */
    private fun readSyncResponse(stream: AdbStream, timeoutMs: Long): ByteArray? {
        val deadline = System.currentTimeMillis() + timeoutMs
        val buffer = java.io.ByteArrayOutputStream()

        while (buffer.size() < 4) {
            val remaining = deadline - System.currentTimeMillis()
            if (remaining <= 0) break

            val data = stream.dataQueue.poll(remaining, TimeUnit.MILLISECONDS) ?: continue
            buffer.write(data)
        }

        return if (buffer.size() >= 4) buffer.toByteArray() else null
    }

    fun setOnStateChangedListener(listener: (String, String?, String) -> Unit) {
        onStateChanged = listener
    }

    private fun notifyState(state: String, message: String?, log: String) {
        log("notifyState: $state - $message")
        onStateChanged?.invoke(state, message, log)
    }

    fun getStream(localId: Int): AdbStream? = streams[localId]

    fun isAdbConnected(): Boolean = isConnected

    // --- Control write queue (serialized, flow-control compliant) ---

    private val controlWriteQueue = LinkedBlockingQueue<Pair<Int, ByteArray>>()
    private var controlWriterThread: Thread? = null
    private val controlWriterRunning = AtomicBoolean(false)

    /**
     * Enqueue a control packet to be sent in order, respecting ADB flow control
     * (1 unconfirmed A_WRTE per stream at a time). Does not block the caller.
     */
    fun enqueueControlWrite(localId: Int, packet: ByteArray) {
        controlWriteQueue.offer(localId to packet)
        startControlWriterIfNeeded()
    }

    private fun startControlWriterIfNeeded() {
        if (controlWriterRunning.get()) return
        controlWriterRunning.set(true)
        controlWriterThread = thread(name = "AdbControlWriter", isDaemon = true) {
            log("ControlWriter: started")
            while (controlWriterRunning.get() && !disconnected.get()) {
                try {
                    val (localId, packet) = controlWriteQueue.poll(2, TimeUnit.SECONDS) ?: continue
                    writeStream(localId, packet, waitForOkay = true, timeoutMs = 3000)
                } catch (e: Exception) {
                    log("ControlWriter error: ${e.message}")
                }
            }
            log("ControlWriter: exiting")
        }
    }

    fun stopControlWriter() {
        controlWriterRunning.set(false)
        controlWriteQueue.clear()
        controlWriterThread?.interrupt()
        controlWriterThread = null
    }

    // --- Video read loop ---

    private var videoReaderThread: Thread? = null
    private val videoRunning = AtomicBoolean(false)

    /**
     * Read video packets from an already-open scrcpy stream.
     * Calls onPacket(headerValue, payload) for each decoded packet.
     * Runs on a background thread. Call stopVideoReadLoop() to stop.
     */
    fun startVideoReadLoop(localId: Int, onPacket: (Long, ByteArray) -> Unit, onError: (String) -> Unit) {
        if (videoRunning.get()) {
            log("startVideoReadLoop: already running")
            return
        }
        videoRunning.set(true)
        videoReaderThread = thread(name = "ScrcpyVideoReader", isDaemon = true) {
            log("VideoReader: started for stream $localId")
            var packetCount = 0
            // Reuse header buffer across iterations
            val headerBuf = ByteArray(12)
            val headerBB = ByteBuffer.wrap(headerBuf).order(ByteOrder.BIG_ENDIAN)
            // Reuse payload buffer pool to avoid allocation per frame
            var lastPayloadSize = 0
            var payloadBuf = ByteArray(0)
            try {
                while (videoRunning.get() && isConnected && isStreamOpen(localId)) {
                    // Read 12-byte frame header into reusable buffer
                    val headerRead = readStreamExactInto(localId, headerBuf, 12)
                    if (headerRead < 12) {
                        if (!quietMode) log("VideoReader: readStreamExact returned $headerRead bytes, stream closed or timeout")
                        break
                    }

                    headerBB.position(0)
                    val headerValue = headerBB.long   // flags + pts
                    val size = headerBB.int            // payload size

                    if (size <= 0 || size > 10 * 1024 * 1024) {
                        log("VideoReader: INVALID size=$size, stopping")
                        break
                    }

                    // Reuse payload buffer if same size, reallocate only if larger
                    if (size > payloadBuf.size) {
                        payloadBuf = ByteArray(size)
                    }
                    val payloadRead = readStreamExactInto(localId, payloadBuf, size)
                    if (payloadRead < size) {
                        if (!quietMode) log("VideoReader: payload read $payloadRead/$size bytes")
                        break
                    }

                    packetCount++
                    onPacket(headerValue, payloadBuf.copyOf(size))
                }
                log("VideoReader: loop ended, received $packetCount packets")
            } catch (e: InterruptedException) {
                log("VideoReader: interrupted (stop solicitado normalmente)")
            } catch (e: Exception) {
                log("VideoReader EXCEPTION: ${e.javaClass.simpleName}: ${e.message}")
                onError(e.message ?: "video read loop failed: ${e.javaClass.simpleName}")
            }
            log("VideoReader: exiting")
            videoRunning.set(false)
        }
    }

    fun stopVideoReadLoop() {
        videoRunning.set(false)
        videoReaderThread?.interrupt()
        videoReaderThread = null
    }

    /**
     * Read exactly n bytes from a stream into an existing buffer.
     * Avoids allocation per call — used in the hot video read loop.
     * Returns number of bytes read, or -1 on error.
     */
    fun readStreamExactInto(localId: Int, out: ByteArray, n: Int): Int {
        val stream = streams[localId] ?: return -1
        var offset = 0
        while (offset < n) {
            val chunk = stream.dataQueue.poll(15, TimeUnit.SECONDS) ?: return -1
            val toCopy = minOf(chunk.size, n - offset)
            System.arraycopy(chunk, 0, out, offset, toCopy)
            offset += toCopy
            if (toCopy < chunk.size) {
                stream.dataQueue.addFirst(chunk.copyOfRange(toCopy, chunk.size))
            }
        }
        return offset
    }

    /**
     * Read exactly n bytes from a stream, accumulating from dataQueue.
     * Uses addFirst() to put back leftover bytes from partial chunks.
     * Returns null if stream closes before n bytes are read.
     */
    fun readStreamExact(localId: Int, n: Int): ByteArray? {
        val stream = streams[localId] ?: return null
        val out = ByteArray(n)
        var offset = 0
        while (offset < n) {
            val chunk = stream.dataQueue.poll(15, TimeUnit.SECONDS) ?: return null
            val toCopy = minOf(chunk.size, n - offset)
            System.arraycopy(chunk, 0, out, offset, toCopy)
            offset += toCopy
            if (toCopy < chunk.size) {
                // Leftover bytes belong to the next packet - put them back at the front
                stream.dataQueue.addFirst(chunk.copyOfRange(toCopy, chunk.size))
            }
        }
        return out
    }
}

data class AdbStream(
    val localId: Int,
    var remoteId: Int? = null,
    val dataQueue: LinkedBlockingDeque<ByteArray> = LinkedBlockingDeque(),
    val okayReceived: CountDownLatch = CountDownLatch(1),
    val closed: AtomicBoolean = AtomicBoolean(false),
    val closeReceived: CountDownLatch = CountDownLatch(1),
    val writeOkayQueue: LinkedBlockingQueue<Int> = LinkedBlockingQueue()
) {
    @Volatile var okayRemoteId: Int = 0
}
