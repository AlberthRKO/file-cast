# Módulo de transferencia Android

## Alcance implementado

La acción **Transferencia de archivos** del detalle conecta un dispositivo Android mediante ADB y abre un explorador de solo lectura ligado a `requisitionId` y `sessionId`. Si la sesión ya fue autorizada por el mirror, reutiliza el transporte y la clave RSA; si no existe conexión, solicita permiso y autorización antes de continuar.

El explorador inicia en **Contenido común**, con accesos directos a:

```text
/sdcard/DCIM
/sdcard/Pictures
/sdcard/Movies
/sdcard/Download
```

El selector **Exploración completa** abre `/sdcard` y permite recorrer todas las
carpetas de la memoria compartida que el usuario `shell` pueda leer. Este modo no
convierte ADB en root: `Android/data`, `Android/obb`, datos privados de apps y
áreas protegidas pueden devolver acceso denegado según la versión y fabricante.

No ofrece acceso a datos privados de aplicaciones, root, bypass de bloqueo, eliminación, movimiento ni modificación remota.

Antes de seleccionar, los archivos compatibles muestran una acción de vista
previa con el icono de ojo. Tocar el card o su checkbox selecciona el archivo;
el ojo es la única acción que abre el contenido. La app descarga una única copia a
`cacheDir/file_previews/<requisitionId>/<sessionId>/` y abre un bottom sheet:

- imágenes con zoom y desplazamiento;
- videos con reproducción, pausa y scrubbing;
- audios MP3, M4A, AAC, WAV, OGG/OGA, OPUS, FLAC y AMR con reproducción,
  pausa, progreso y búsqueda temporal;
- PDF con visor paginado y contraste entre la hoja blanca y el fondo;
- DOCX como vista de lectura del texto contenido en `word/document.xml`;
- TXT, CSV, JSON, XML y LOG como páginas de lectura.

El preview no se registra como evidencia, se limita a 10 MB para texto, 25 MB
para DOCX, 64 MB para imágenes/PDF, 128 MB para audios y 256 MB para videos,
y se elimina al cerrar la hoja o preparar otro archivo. La selección definitiva sigue separada
y solo **Transferir a la requisa** crea la evidencia con hash. DOCX no conserva
maquetación, tablas o imágenes con fidelidad de Microsoft Word.

La hoja no se cierra por arrastre ni al tocar el fondo. Su checkbox permanece
junto a la acción **X**, actualiza la selección sin cerrar el preview y el visor
PDF captura los gestos verticales para recorrer todas sus páginas.

En imágenes y videos, la hoja calcula su altura a partir de las dimensiones
reales del medio y anima el ajuste dentro de límites seguros. Una evidencia
horizontal usa una hoja más baja; una vertical puede crecer hasta el 90 % de la
ventana. PDF y documentos mantienen una zona alta de lectura. El fondo de
documentos usa el color semántico del tema y cada página se representa como una
hoja blanca separada, con sombra, margen y numeración. La paginación de DOCX y
texto es visual y aproximada porque no existe un motor de Microsoft Word.

El visor PDF usa `flutter_pdfview` sobre los visores nativos Android/iOS. Se
evita `pdfrx 2.1.13` porque su integración CMake/PDFium fallaba al preparar
`armeabi-v7a` con el NDK 27 del proyecto.

## Arquitectura

```text
FileTransferView
  -> FileTransferViewModel
  -> AcquisitionRepository
  -> AndroidAcquisitionPlatformService
  -> AdbClient / MethodChannel
  -> UsbPlugin
  -> AdbSyncClient
```

Estructura principal:

```text
lib/ui/features/acquisition/transfer/
├── view_models/file_transfer_view_model.dart
├── views/file_transfer_view.dart
└── widgets/
    ├── file_transfer_widgets.dart
    └── remote_file_preview_sheet.dart

lib/data/services/remote_document_preview_service.dart

android/app/src/main/kotlin/com/fiscalia/file_cast/sync/
├── AdbSyncClient.kt
└── SyncPacketReader.kt
```

`AppCardSurface`, `AppActionButton` y `FolderBackground` permanecen en `ui/core/widgets` porque representan contratos visuales compartidos. Breadcrumbs, filas remotas, selección y progreso permanecen dentro del módulo por depender de su dominio.

## Protocolo y almacenamiento

- `LIST` obtiene entradas de directorio y sus metadatos básicos.
- La validación nativa admite únicamente `/sdcard` y sus descendientes; rechaza rutas fuera de la memoria compartida y traversal.
- `STAT` confirma tipo, tamaño y fecha antes de transferir.
- `RECV` recibe bloques `DATA` hasta `DONE`.
- `SyncPacketReader` conserva excedentes y tolera fragmentación/coalescencia de paquetes ADB.
- Los bytes no atraviesan MethodChannel; Kotlin escribe directamente en almacenamiento privado.
- Los previews usan el mismo `RECV`, pero escriben en caché y nunca pasan por el registro de evidencias.
- Cada archivo se escribe como `.part`, calcula SHA-256 en streaming, ejecuta `fsync` y se renombra dentro del mismo directorio.
- Una cancelación cierra el stream activo y elimina el parcial.
- Los archivos completos se registran en el repositorio de detalle y este notifica a su ViewModel para refrescar la galería al volver.

Destino local:

```text
filesDir/evidence/<requisitionId>/<sessionId>/
```

La transferencia es secuencial para no saturar el enlace OTG compartido con scrcpy. El lote está limitado a 200 elementos, conserva un margen libre de 64 MiB y ADB Sync v1 limita cada tamaño declarado a 32 bits.

## Responsive

- Compact y medium muestran breadcrumb, contenido en una columna y barra segura inferior con selección/progreso.
- Expanded y large usan ubicaciones a la izquierda, browser central y selección/progreso a la derecha.
- El selector conserva los accesos comunes por defecto y, al activarse, abre directamente la raíz compartida completa.
- Las listas usan builders, targets táctiles de al menos 48 dp y el layout depende de constraints, no de orientación ni tipo físico.
- Colores, sombras, radios, tipografía e iconos SVG provienen del tema y de los widgets compartidos.

## Navegación

```text
/requisitions/:requisitionId/acquisitions/:sessionId/connect?destination=transfer
/requisitions/:requisitionId/acquisitions/:sessionId/transfer
```

La pantalla de transferencia ofrece fallback visible si el transporte ya no está activo y permite volver a conectar. No depende de objetos efímeros en `extra`.

## Deuda

- Validación en hardware OTG con archivos de 0 B, Unicode, 1 GB, lotes y desconexión.
- Persistencia transaccional del catálogo, cifrado, ledger y outbox.
- Deduplicación física por hash y receipts del backend.
- Reanudación: ADB Sync v1 no permite continuar desde un offset; el archivo activo se reinicia.
- Alternativa companion/SAF para consentimiento explícito y contenido no visible para `shell`.
- Preview fiel de DOC legado, XLS/XLSX y PPT/PPTX; requiere conversión segura o
  un motor ofimático y no debe confundirse con la evidencia original.
- La reproducción final de contenedores y códecs multimedia depende de los
  decodificadores disponibles en el dispositivo donde se ejecuta File Cast.

## Validación

Por regla del repositorio no se ejecutaron tests, `flutter analyze`, `flutter run`, builds nativos ni generadores. Se aplicó `dart format`, revisión de referencias y `git diff --check`. La validación funcional del protocolo debe realizarse en hardware OTG real.
