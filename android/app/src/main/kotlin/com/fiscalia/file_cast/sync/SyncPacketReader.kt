package com.fiscalia.file_cast.sync

import com.fiscalia.file_cast.usb.AdbStream
import java.io.ByteArrayOutputStream
import java.io.EOFException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/** Reads the byte-oriented ADB sync protocol independently from ADB WRTE chunks. */
internal class SyncPacketReader(private val stream: AdbStream) {
    private var remainder = ByteArray(0)

    fun readExact(byteCount: Int, timeoutMs: Long): ByteArray {
        require(byteCount >= 0) { "byteCount must be non-negative" }
        if (byteCount == 0) return ByteArray(0)

        val output = ByteArrayOutputStream(byteCount)
        if (remainder.isNotEmpty()) {
            val consumed = minOf(byteCount, remainder.size)
            output.write(remainder, 0, consumed)
            remainder = remainder.copyOfRange(consumed, remainder.size)
        }

        val deadline = System.currentTimeMillis() + timeoutMs
        while (output.size() < byteCount) {
            val remainingTime = deadline - System.currentTimeMillis()
            if (remainingTime <= 0) {
                throw TimeoutException("Timeout reading ADB sync packet (${output.size()}/$byteCount)")
            }
            val chunk = stream.dataQueue.poll(minOf(remainingTime, 250L), TimeUnit.MILLISECONDS)
            if (chunk == null) {
                if (stream.closed.get()) throw EOFException("ADB sync stream closed")
                continue
            }
            val required = byteCount - output.size()
            val consumed = minOf(required, chunk.size)
            output.write(chunk, 0, consumed)
            if (consumed < chunk.size) {
                remainder = chunk.copyOfRange(consumed, chunk.size)
            }
        }
        return output.toByteArray()
    }
}
