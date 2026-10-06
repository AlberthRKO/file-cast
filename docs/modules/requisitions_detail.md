# Módulo Detalle de Requisa

## Flujo actual

`/requisitions/:requisitionId` muestra la información de la requisa y sus evidencias en una única vista continua. La cabecera fija concentra el identificador, estado y contexto de negocio: si existe caso actual muestra el CUD, delito, tipo/división y sujetos; si no existe caso muestra la persona y su CI. La vista consulta `GET /api/v1/requisitions/:id`, convierte el envelope HTTP a modelos de dominio y mezcla únicamente las evidencias locales pendientes que todavía no aparecen en el servidor.

La cabecera no repite información en el cuerpo desplazable. Los sujetos y participantes se muestran directamente cuando hay uno y mediante hojas inferiores cuando hay varios; las colecciones vacías se ocultan. Los participantes provienen de los accesos activos que entrega el backend (`actorId` y `role`); para el actor de la sesión se resuelve el nombre desde el perfil autenticado y, si el API no entrega nombre para otro actor, se usa una etiqueta neutra sin exponer el ID. La ubicación muestra referencia y coordenadas, y reutiliza `RequisitionLocationViewer` para abrir el mapa. En requisas por persona y mientras el estado permite edición aparece **Vincular a un CUD**: la búsqueda reutiliza `POST /api/v1/file-cast/casos/list` y confirma el vínculo mediante `POST /api/v1/requisitions/:id/case-links`, enviando el snapshot de tipo, división, sujetos y funcionarios.

Las evidencias se agrupan en **Imágenes**, **Videos** y **Archivos**. Archivos incluye documentos, audios y formatos adicionales. Antes de los listados se muestran cards de carpeta con cantidad y peso acumulado por categoría. Cada sección presenta como máximo cinco elementos y ofrece **Ver todo**, que abre un `ModalBottomSheet` responsive con el listado completo.

Los `ModalBottomSheet` del detalle comparten el lenguaje del formulario de creación: fondo `Theme.cardColor`, encabezado con icono SVG, título, subtítulo y botón de cierre. Los archivos y acciones usan cards horizontales compactos para evitar espacios vacíos.

La tarjeta resumen está integrada al encabezado bajo el `AppBar`, dentro de una superficie `cardColor` con radios inferiores. En ancho medio/expandido agrupa delito y tipo en una misma fila; las acciones de sujetos, participantes y ubicación usan botones iconográficos con tooltip para mantener la cabecera compacta. El vínculo a CUD reutiliza el degradado de los CTA principales del listado. Los cards de resumen, evidencias, estados vacíos y acciones no usan borde: conservan la misma sombra suave de la tarjeta fija.

La información de la requisa se muestra inicialmente y puede ocultarse o restaurarse desde el botón de información del `AppBar`. El cambio usa `AnimatedSize` para liberar espacio vertical a las evidencias sin un salto brusco. Los botones circulares de consulta permanecen junto al texto con un espaciado corto; el área táctil conserva el tamaño accesible aunque el círculo visible sea compacto.

Importar archivos permite seleccionar múltiples elementos con el selector del sistema. Antes de confirmar se muestra un diálogo responsive con miniaturas, nombres y tamaño total. La sesión `FILE_CAST`/`SYSTEM_PICKER` se crea únicamente al confirmar ese preview; cancelar la selección no crea sesiones ni modifica la requisa. Al confirmar, el lote se cifra y se guarda en la outbox local, y la subida continúa en segundo plano para que el usuario pueda seguir usando la aplicación.

La cabecera fija muestra el progreso del lote (`Subiendo 2 de 4 archivos`), el archivo actual y una barra de avance por archivo. Si una carga falla, conserva la evidencia local, muestra los pendientes y habilita el reintento. El sincronizador emite progreso por lote y publica un único cambio al finalizar, evitando un `GET` del detalle por cada evidencia. Las tarjetas son accionables: muestran miniaturas de imágenes locales —incluidas imágenes FCE descifradas temporalmente— y abren una vista previa para imágenes, videos, audio, PDF y texto/DOCX. Los temporales descifrados o descargados se eliminan al cerrar la vista previa. Las evidencias cifradas solo pueden previsualizarse en el dispositivo que conserva la envoltura de clave local.

La vista previa se abre como diálogo responsive con ancho máximo en pantallas grandes y márgenes visibles en móviles; el procesamiento del archivo conserva la misma preparación asíncrona y limpieza temporal. En Android, los controles existentes de `video_player` usan `video_player_media_kit` como backend basado en FFmpeg/libmpv para ampliar la compatibilidad de contenedores y códecs; el archivo sigue siendo local y temporal durante la vista previa.

Las grabaciones del mirror se remultiplexan desde el H.264 Annex-B de scrcpy a muestras AVC/AVCC antes de escribirlas en MP4. Al salir de la pantalla de mirror se libera la textura, el decoder y la sesión nativa; al volver se crea una textura y un decoder nuevos, evitando mostrar el último frame congelado con el canal táctil todavía activo.

- El botón flotante **+** abre un `ModalBottomSheet` con las tres acciones de adquisición mientras la requisa está en `DRAFT` o `IN_PROGRESS`.
- **Captura de pantalla:** crea o reutiliza una sesión `OPEN` en el backend con `ANDROID`/`USB_OTG_SCRCPY` y abre la conexión asociada a `requisitionId` y `sessionId`.
- **Transferencia de archivos:** crea o reutiliza la misma sesión con `ANDROID`/`USB_OTG_ADB` y continúa en `/requisitions/:requisitionId/acquisitions/:sessionId/transfer`.
- **Importar archivos:** selecciona uno o varios archivos, muestra el preview de confirmación, crea o reutiliza una sesión de tipo `FILE_CAST`/`SYSTEM_PICKER` al aceptar, cifra y registra el lote en el outbox local, y muestra su progreso y estado en la cabecera fija.
- **Sellar requisa:** solicita confirmación y llama `POST /api/v1/requisitions/:id/finalize`; el backend valida el caso y que las evidencias estén disponibles antes de cambiar el estado a `SEALED`.

## Estructura

```text
lib/domain/models/requisition_detail.dart
lib/domain/models/evidence_upload_progress.dart
lib/domain/repositories/requisition_detail_repository.dart
lib/data/services/evidence_picker_service.dart
lib/data/services/evidence_sync_service.dart
lib/data/services/requisition_detail_service.dart
lib/data/services/evidence_preview_service.dart
lib/data/services/requisition_service.dart
lib/data/repositories/remote_requisition_detail_repository.dart
lib/data/repositories/remote_requisition_repository.dart
lib/domain/services/evidence_preview_service.dart
lib/ui/features/requisitions/detail/
├── widgets/evidence_preview_sheet.dart
├── widgets/import_evidence_preview_dialog.dart
├── view_models/requisition_detail_view_model.dart
└── views/
    └── requisition_detail_view.dart
lib/ui/core/widgets/evidence_thumbnail.dart

lib/ui/features/acquisition/transfer/
├── view_models/file_transfer_view_model.dart
├── views/file_transfer_view.dart
└── widgets/file_transfer_widgets.dart
```

## Límite iOS

En iOS/iPadOS se omite la comprobación ADB/OTG, porque el canal Android no existe. La pantalla de conexión informa la limitación y devuelve al detalle; importar archivos permanece disponible mediante los selectores del sistema.

## Deuda

- El detalle, sesiones, vínculo a caso y evidencias remotas ya se leen/escriben contra el backend; la importación local usa selección múltiple, preview de confirmación, outbox cifrada y progreso de sincronización por lote. Falta validar el flujo probatorio completo en un entorno integrado.
- La galería y el preview remoto de evidencias sin cifrado ya están conectados. Las evidencias cifradas de otro dispositivo no se pueden previsualizar porque el backend no devuelve la envoltura de clave del dispositivo emisor.
- La compatibilidad de video depende de que el archivo no esté corrupto, protegido por DRM o use un códec propietario ausente del build nativo; `media_kit` amplía la cobertura, pero no convierte automáticamente archivos dañados.
- El cierre explícito de una sesión (`POST /api/v1/requisitions/:id/sessions/:sessionId/complete`) todavía no está conectado al ciclo de salida de las pantallas de adquisición.
- Transferencia ADB desde almacenamiento compartido está implementada como vertical local; falta validación física, persistencia probatoria y backend.
- ADB/scrcpy conserva alcance Android; iOS requiere app compañera o puente macOS.
