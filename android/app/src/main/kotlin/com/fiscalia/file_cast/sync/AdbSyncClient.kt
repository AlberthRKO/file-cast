package com.fiscalia.file_cast.sync

import com.fiscalia.file_cast.usb.UsbAdbTransport
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean

data class RemoteFileEntry(
    val path: String,
    val name: String,
    val mode: Int,
    val byteLength: Long,
    val modifiedAtSeconds: Long,
) {
    val isDirectory: Boolean get() = mode and 0xF000 == 0x4000
    val isRegularFile: Boolean get() = mode and 0xF000 == 0x8000

    fun toMap(): Map<String, Any> = mapOf(
        "path" to path,
        "name" to name,
        "mode" to mode,
        "byteLength" to byteLength,
        "modifiedAtSeconds" to modifiedAtSeconds,
        "isDirectory" to isDirectory,
        "isRegularFile" to isRegularFile,
    )
}

data class PulledFile(
    val name: String,
    val remotePath: String,
    val localPath: String,
    val byteLength: Long,
    val sha256: String,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "name" to name,
        "remotePath" to remotePath,
        "path" to localPath,
        "byteLength" to byteLength,
        "sha256" to sha256,
    )
}

/** Implements the read-only portion of ADB sync v1 used by File Cast. */
class AdbSyncClient(private val transport: UsbAdbTransport) {
    companion object {
        private const val DEFAULT_TIMEOUT_MS = 30_000L
        private const val MAX_NAME_BYTES = 4 * 1024
        private const val MAX_DATA_CHUNK = 1024 * 1024
        private const val MAX_FILE_BYTES = 0xFFFF_FFFFL
        private const val SHARED_STORAGE_ROOT = "/sdcard"
    }

    private val cancelled = AtomicBoolean(false)
    @Volatile private var activeStreamId: Int? = null

    fun cancel() {
        cancelled.set(true)
        activeStreamId?.let(transport::closeStream)
    }

    fun resetCancellation() {
        cancelled.set(false)
    }

    @Synchronized
    fun listDirectory(remotePath: String, timeoutMs: Long = DEFAULT_TIMEOUT_MS): List<RemoteFileEntry> {
        ensureNotCancelled()
        val safePath = validateRemotePath(remotePath)
        val stream = transport.openStream("sync:", timeoutMs)
        activeStreamId = stream.localId
        val reader = SyncPacketReader(stream)
        try {
            transport.writeStream(stream.localId, request("LIST", safePath), timeoutMs = timeoutMs)
            val entries = mutableListOf<RemoteFileEntry>()
            while (true) {
                ensureNotCancelled()
                when (val id = readId(reader, timeoutMs)) {
                    "DENT" -> {
                        val metadata = littleEndian(reader.readExact(16, timeoutMs))
                        val mode = metadata.int
                        val size = Integer.toUnsignedLong(metadata.int)
                        val modified = Integer.toUnsignedLong(metadata.int)
                        val nameLength = metadata.int
                        if (nameLength !in 1..MAX_NAME_BYTES) {
                            throw IOException("Invalid remote file name length: $nameLength")
                        }
                        val name = String(reader.readExact(nameLength, timeoutMs), Charsets.UTF_8)
                        if (name == "." || name == ".." || name.indexOf('\u0000') >= 0) continue
                        val path = if (safePath.endsWith('/')) "$safePath$name" else "$safePath/$name"
                        entries += RemoteFileEntry(path, name, mode, size, modified)
                    }
                    "DONE" -> break
                    "FAIL" -> throw IOException(readFailure(reader, timeoutMs))
                    else -> throw IOException("Unexpected ADB sync response: $id")
                }
            }
            return entries.sortedWith(compareByDescending<RemoteFileEntry> { it.isDirectory }.thenBy { it.name.lowercase() })
        } finally {
            activeStreamId = null
            transport.closeStream(stream.localId)
        }
    }

    @Synchronized
    fun stat(remotePath: String, timeoutMs: Long = DEFAULT_TIMEOUT_MS): RemoteFileEntry {
        ensureNotCancelled()
        val safePath = validateRemotePath(remotePath)
        val stream = transport.openStream("sync:", timeoutMs)
        activeStreamId = stream.localId
        val reader = SyncPacketReader(stream)
        try {
            transport.writeStream(stream.localId, request("STAT", safePath), timeoutMs = timeoutMs)
            return when (val id = readId(reader, timeoutMs)) {
                "STAT" -> {
                    val metadata = littleEndian(reader.readExact(12, timeoutMs))
                    val mode = metadata.int
                    val size = Integer.toUnsignedLong(metadata.int)
                    val modified = Integer.toUnsignedLong(metadata.int)
                    RemoteFileEntry(safePath, safePath.substringAfterLast('/'), mode, size, modified)
                }
                "FAIL" -> throw IOException(readFailure(reader, timeoutMs))
                else -> throw IOException("Unexpected ADB sync response: $id")
            }
        } finally {
            activeStreamId = null
            transport.closeStream(stream.localId)
        }
    }

    @Synchronized
    fun pullFile(
        remotePath: String,
        destinationDirectory: File,
        knownRemote: RemoteFileEntry? = null,
        timeoutMs: Long = DEFAULT_TIMEOUT_MS,
        onProgress: (Long) -> Unit,
    ): PulledFile {
        val safePath = validateRemotePath(remotePath)
        val remote = knownRemote ?: stat(safePath, timeoutMs)
        if (!remote.isRegularFile) throw IOException("The selected item is not a regular file")
        if (remote.byteLength > MAX_FILE_BYTES) throw IOException("The selected file exceeds the ADB sync v1 limit")

        destinationDirectory.mkdirs()
        val safeName = safeFileName(remote.name)
        val destination = uniqueDestination(destinationDirectory, safeName)
        val partial = File(destinationDirectory, ".${destination.name}.part")
        if (partial.exists()) partial.delete()

        val stream = transport.openStream("sync:", timeoutMs)
        activeStreamId = stream.localId
        val reader = SyncPacketReader(stream)
        val digest = MessageDigest.getInstance("SHA-256")
        var received = 0L
        try {
            transport.writeStream(stream.localId, request("RECV", safePath), timeoutMs = timeoutMs)
            FileOutputStream(partial).use { output ->
                while (true) {
                    ensureNotCancelled()
                    when (val id = readId(reader, timeoutMs)) {
                        "DATA" -> {
                            val length = littleEndian(reader.readExact(4, timeoutMs)).int
                            if (length !in 0..MAX_DATA_CHUNK) throw IOException("Invalid ADB sync DATA length: $length")
                            val data = reader.readExact(length, timeoutMs)
                            received += data.size
                            if (received > MAX_FILE_BYTES) throw IOException("The transferred file exceeds the ADB sync v1 limit")
                            output.write(data)
                            digest.update(data)
                            onProgress(received)
                        }
                        "DONE" -> {
                            reader.readExact(4, timeoutMs) // remote mtime
                            break
                        }
                        "FAIL" -> throw IOException(readFailure(reader, timeoutMs))
                        else -> throw IOException("Unexpected ADB sync response: $id")
                    }
                }
                output.flush()
                output.fd.sync()
            }
            ensureNotCancelled()
            if (remote.byteLength > 0 && received != remote.byteLength) {
                throw IOException("Incomplete file: expected ${remote.byteLength}, received $received")
            }
            if (!partial.renameTo(destination)) throw IOException("Could not finalize transferred file")
            return PulledFile(
                name = destination.name,
                remotePath = safePath,
                localPath = destination.absolutePath,
                byteLength = received,
                sha256 = digest.digest().joinToString("") { "%02x".format(it) },
            )
        } catch (error: Throwable) {
            partial.delete()
            if (cancelled.get() && error !is CancellationException) {
                throw CancellationException("Transfer cancelled")
            }
            throw error
        } finally {
            activeStreamId = null
            transport.closeStream(stream.localId)
        }
    }

    private fun ensureNotCancelled() {
        if (cancelled.get()) throw CancellationException("Transfer cancelled")
    }

    private fun request(command: String, path: String): ByteArray {
        val pathBytes = path.toByteArray(Charsets.UTF_8)
        return ByteBuffer.allocate(8 + pathBytes.size)
            .order(ByteOrder.LITTLE_ENDIAN)
            .put(command.toByteArray(Charsets.US_ASCII))
            .putInt(pathBytes.size)
            .put(pathBytes)
            .array()
    }

    private fun readId(reader: SyncPacketReader, timeoutMs: Long): String =
        String(reader.readExact(4, timeoutMs), Charsets.US_ASCII)

    private fun readFailure(reader: SyncPacketReader, timeoutMs: Long): String {
        val length = littleEndian(reader.readExact(4, timeoutMs)).int
        if (length !in 0..64 * 1024) return "Invalid ADB sync failure"
        return String(reader.readExact(length, timeoutMs), Charsets.UTF_8)
    }

    private fun littleEndian(bytes: ByteArray): ByteBuffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)

    private fun validateRemotePath(path: String): String {
        if (path.indexOf('\u0000') >= 0 || path.contains('\\')) throw SecurityException("Invalid remote path")
        val segments = path.split('/').filter { it.isNotEmpty() && it != "." }
        if (segments.any { it == ".." }) throw SecurityException("Remote path traversal is not allowed")
        val normalized = "/" + segments.joinToString("/")
        val allowed = normalized == SHARED_STORAGE_ROOT || normalized.startsWith("$SHARED_STORAGE_ROOT/")
        if (!allowed) throw SecurityException("Remote path is outside shared internal storage")
        return normalized
    }

    private fun safeFileName(name: String): String {
        val sanitized = name.replace(Regex("[^\\p{L}\\p{N}._() -]"), "_").trim().trimStart('.')
        return sanitized.ifBlank { "archivo" }.take(180)
    }

    private fun uniqueDestination(directory: File, name: String): File {
        var candidate = File(directory, name)
        if (!candidate.exists()) return candidate
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val extension = if (dot > 0) name.substring(dot) else ""
        var suffix = 1
        while (candidate.exists()) {
            candidate = File(directory, "$base ($suffix)$extension")
            suffix += 1
        }
        return candidate
    }
}
