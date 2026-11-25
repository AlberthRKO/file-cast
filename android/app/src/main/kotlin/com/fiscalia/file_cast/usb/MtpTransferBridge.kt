package com.fiscalia.file_cast.usb

import android.content.Context
import android.hardware.usb.UsbManager
import android.hardware.usb.UsbDevice
import android.mtp.MtpConstants
import android.mtp.MtpDevice
import android.mtp.MtpObjectInfo
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/** Read-only access to the objects actually published by a USB MTP/PTP target. */
internal class MtpTransferBridge(private val context: Context) {
    private val manager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val lock = Any()
    private var device: MtpDevice? = null
    private var deviceName: String? = null
    private val cancelled = AtomicBoolean(false)
    private val busy = AtomicBoolean(false)
    private val connectionVersion = AtomicInteger(0)

    fun isConnected(name: String?): Boolean = synchronized(lock) {
        name != null && name == deviceName && device != null &&
            manager.deviceList.values.any { it.deviceName == name }
    }

    fun connect(name: String) {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            "La transferencia MTP de File Cast requiere Android 7 o posterior"
        }
        val version = connectionVersion.incrementAndGet()
        synchronized(lock) {
            closeLocked()
        }
        val deadline = SystemClock.elapsedRealtime() + 90_000L
        while (SystemClock.elapsedRealtime() < deadline) {
            check(connectionVersion.get() == version) { "Se canceló la conexión MTP/PTP" }
            val usb = manager.deviceList.values.firstOrNull { it.deviceName == name }
                ?: error("El dispositivo USB ya no está conectado")
            check(isImagingDevice(usb)) { "El dispositivo no expone MTP/PTP" }
            check(manager.hasPermission(usb)) { "File Cast necesita permiso USB para este dispositivo" }
            val connection = manager.openDevice(usb)
            if (connection != null) {
                val candidate = MtpDevice(usb)
                var retained = false
                var opened = false
                try {
                    opened = candidate.open(connection)
                    if (opened) {
                        // El iPad puede publicar el almacenamiento antes de que el usuario
                        // confirme "Permitir". Una carpeta legible confirma el acceso real.
                        val readable = candidate.storageIds?.any { storageId ->
                            candidate.getObjectHandles(storageId, 0, -1)
                                ?.any { handle -> candidate.getObjectInfo(handle) != null } == true
                        } == true
                        if (readable) {
                            synchronized(lock) {
                                check(connectionVersion.get() == version) {
                                    "Se canceló la conexión MTP/PTP"
                                }
                                device = candidate
                                deviceName = name
                                retained = true
                            }
                            return
                        }
                    }
                } catch (error: RuntimeException) {
                    if (connectionVersion.get() != version) throw error
                    // La sesión puede rechazar consultas hasta que el iPad sea autorizado.
                } finally {
                    if (!retained) {
                        if (opened) candidate.close()
                        connection.close()
                    }
                }
            }
            Thread.sleep(600)
        }
        error("El dispositivo no publicó carpetas accesibles. Desbloquéalo y permite el acceso.")
    }

    fun disconnect(name: String? = null) {
        connectionVersion.incrementAndGet()
        synchronized(lock) {
            if (name == null || name == deviceName) closeLocked()
        }
    }

    private fun closeLocked() {
        cancelled.set(true)
        device?.close()
        device = null
        deviceName = null
    }

    fun cancel() { cancelled.set(true) }

    fun list(path: String): List<Map<String, Any>> = synchronized(lock) {
        val mtp = device ?: error("No hay una sesión MTP activa")
        if (path == "mtp:/") {
            return@synchronized (mtp.storageIds ?: intArrayOf()).map { id ->
                val storage = mtp.getStorageInfo(id)
                mapOf(
                    "path" to "mtp:$id:-1",
                    "name" to (storage?.description?.takeIf { it.isNotBlank() } ?: "Almacenamiento $id"),
                    "byteLength" to 0L,
                    "modifiedAtSeconds" to 0L,
                    "isDirectory" to true,
                    "isRegularFile" to false,
                )
            }
        }
        val parts = path.split(':')
        require(parts.size == 3 && parts[0] == "mtp") { "Ubicación MTP inválida" }
        val storageId = parts[1].toInt()
        val parent = parts[2].toInt()
        check((mtp.storageIds ?: intArrayOf()).contains(storageId)) { "Almacenamiento MTP no disponible" }
        if (parent != -1) {
            val folder = mtp.getObjectInfo(parent)
            check(folder != null && folder.storageId == storageId &&
                folder.format == MtpConstants.FORMAT_ASSOCIATION) { "Carpeta MTP no válida" }
        }
        val handles = mtp.getObjectHandles(storageId, 0, parent)
            ?: error("El iPad no permitió listar esta carpeta")
        handles.toList().mapNotNull { handle ->
            mtp.getObjectInfo(handle)?.let { info ->
                val folder = info.format == MtpConstants.FORMAT_ASSOCIATION
                mapOf(
                    "path" to "mtp:$storageId:$handle",
                    "name" to info.name,
                    "byteLength" to if (folder) 0L else objectSize(info),
                    "modifiedAtSeconds" to info.dateModified / 1000L,
                    "isDirectory" to folder,
                    "isRegularFile" to !folder,
                )
            }
        }
    }

    fun pull(
        requisitionId: String,
        sessionId: String,
        paths: List<String>,
        previewOnly: Boolean,
        onProgress: (Map<String, Any>) -> Unit,
    ): Map<String, Any> {
        check(busy.compareAndSet(false, true)) { "Ya existe una transferencia en curso" }
        cancelled.set(false)
        val completed = mutableListOf<Map<String, Any>>()
        val failures = mutableListOf<Map<String, String>>()
        try {
            require(paths.isNotEmpty() && paths.size <= 200) { "Lote MTP inválido" }
            require(!previewOnly || paths.size == 1) { "Vista previa MTP inválida" }
            val safeRequisition = requisitionId.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val safeSession = sessionId.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val directory = if (previewOnly) {
                File(context.cacheDir, "file_previews/$safeRequisition/$safeSession")
            } else {
                File(context.filesDir, "evidence/$safeRequisition/$safeSession")
            }.apply { mkdirs() }
            val entries = synchronized(lock) {
                val mtp = device ?: error("No hay una sesión MTP activa")
                paths.map { path ->
                    val parts = path.split(':')
                    require(parts.size == 3 && parts[0] == "mtp") { "Objeto MTP inválido" }
                    val storage = parts[1].toInt()
                    val handle = parts[2].toInt()
                    val info = mtp.getObjectInfo(handle) ?: error("El archivo ya no está disponible")
                    check(info.storageId == storage && info.format != MtpConstants.FORMAT_ASSOCIATION) {
                        "El objeto MTP cambió o no es un archivo"
                    }
                    Triple(path, handle, info)
                }
            }
            val total = entries.sumOf { objectSize(it.third) }
            check(!previewOnly || total <= 256L * 1024 * 1024) { "El archivo supera el límite de 256 MB para vista previa" }
            check(directory.usableSpace >= total + 64L * 1024 * 1024) { "No hay espacio suficiente para guardar la selección" }
            var transferred = 0L
            for ((index, item) in entries.withIndex()) {
                if (cancelled.get()) break
                val (path, handle, info) = item
                val size = objectSize(info)
                val fileName = info.name.substringAfterLast('/').substringAfterLast('\\').ifBlank { "archivo" }
                val part = File(directory, "${UUID.randomUUID()}.part")
                try {
                    onProgress(mapOf("state" to "transferring", "fileName" to fileName,
                        "fileIndex" to index, "fileCount" to entries.size, "fileBytes" to 0L,
                        "fileTotalBytes" to size, "batchBytes" to transferred, "batchTotalBytes" to total))
                    // Algunos dispositivos iOS tardan en entregar el objeto
                    // después de enumerarlo. Reintentar solo la copia de vista
                    // previa; nunca aceptar una descarga parcial.
                    val attempts = if (previewOnly) 3 else 1
                    var copyError: Exception? = null
                    for (attempt in 1..attempts) {
                        if (cancelled.get()) break
                        try {
                            val ok = synchronized(lock) {
                                val mtp = device ?: error("El dispositivo fue desconectado")
                                ParcelFileDescriptor.open(part, ParcelFileDescriptor.MODE_CREATE or
                                    ParcelFileDescriptor.MODE_WRITE_ONLY or ParcelFileDescriptor.MODE_TRUNCATE).use { descriptor ->
                                    mtp.importFile(handle, descriptor)
                                }
                            }
                            check(ok && !cancelled.get()) { "No se completó la copia MTP" }
                            check(part.length() == size) { "El tamaño copiado no coincide con el objeto MTP" }
                            copyError = null
                            break
                        } catch (error: Exception) {
                            copyError = error
                            part.delete()
                            if (attempt == attempts || cancelled.get()) break
                            Thread.sleep(400L * attempt)
                        }
                    }
                    if (cancelled.get()) error("Se canceló la copia MTP")
                    if (copyError != null) throw copyError
                    java.io.FileOutputStream(part, true).use { it.fd.sync() }
                    val digest = MessageDigest.getInstance("SHA-256")
                    FileInputStream(part).use { input ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            digest.update(buffer, 0, count)
                        }
                    }
                    val output = File(directory, "${UUID.randomUUID()}-$fileName")
                    check(part.renameTo(output)) { "No se pudo confirmar el archivo copiado" }
                    completed += mapOf("name" to fileName, "path" to output.absolutePath,
                        "byteLength" to size, "sha256" to digest.digest().joinToString("") { "%02x".format(it) },
                        "remotePath" to path)
                    transferred += size
                    onProgress(mapOf("state" to "transferring", "fileName" to fileName,
                        "fileIndex" to index, "fileCount" to entries.size, "fileBytes" to size,
                        "fileTotalBytes" to size, "batchBytes" to transferred, "batchTotalBytes" to total))
                } catch (error: Exception) {
                    failures += mapOf("path" to path, "message" to (error.message ?: "Falló la copia MTP"))
                } finally {
                    part.delete()
                }
            }
            return mapOf("files" to completed, "failures" to failures, "cancelled" to cancelled.get())
        } finally {
            busy.set(false)
        }
    }

    companion object {
        fun objectSize(info: MtpObjectInfo): Long =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) info.compressedSizeLong
            else info.compressedSize.toLong() and 0xffffffffL

        fun isImagingDevice(device: UsbDevice): Boolean = (0 until device.interfaceCount).any {
            val iface = device.getInterface(it)
            iface.interfaceClass == 6 && iface.interfaceSubclass == 1 && iface.interfaceProtocol == 1
        }
    }
}
