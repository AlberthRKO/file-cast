# Módulo Detalle de Requisa

## Flujo actual

`/requisitions/:requisitionId` muestra la información de la requisa y sus evidencias en una única vista continua. La cabecera fija queda reducida al CUD o persona, estado de la requisa, sujetos, fiscales investigadores y lugar del hecho. La vista consulta `GET /api/v1/requisitions/:id`, convierte el envelope HTTP a modelos de dominio y mezcla únicamente las evidencias locales pendientes que todavía no aparecen en el servidor.

La cabecera no repite información en el cuerpo desplazable. Los sujetos y fiscales investigadores se muestran directamente cuando hay uno y mediante hojas inferiores cuando hay varios; las colecciones vacías se ocultan. Los fiscales investigadores provienen de los accesos activos que entrega el backend (`actorId` y `role`); para el actor de la sesión se resuelve el nombre desde el perfil autenticado y, si el API no entrega nombre para otro actor, se usa una etiqueta neutra sin exponer el ID. El propietario puede abrir la hoja desde el resumen y cambiar entre **Editor** y **Lector** para otros accesos activos. La fila del propietario permanece protegida; los demás roles solo consultan la lista. Los selectores de alta y edición comparten el diseño del filtro de estado, incluido el icono de nivel de acceso. El cambio usa `PATCH /api/v1/requisitions/:id/accesses/:actorId`, requiere red y se confirma con una lectura remota del detalle. La ubicación prioriza el lugar del hecho del caso y reutiliza `RequisitionLocationViewer` cuando existen coordenadas. En requisas por persona y mientras el estado permite edición aparece **Vincular a un CUD**: la búsqueda reutiliza `POST /api/v1/file-cast/casos/list` y confirma el vínculo mediante `POST /api/v1/requisitions/:id/case-links`, enviando el snapshot de tipo, división, sujetos y funcionarios.

Las evidencias se agrupan en **Imágenes**, **Videos** y **Archivos**. Archivos incluye documentos, audios y formatos adicionales. Antes de los listados se muestran cards de carpeta con cantidad y peso acumulado por categoría. Cada sección presenta como máximo seis elementos y ofrece **Ver todo**, que abre un `ModalBottomSheet` responsive con el listado completo.

Los `ModalBottomSheet` del detalle comparten el lenguaje del formulario de creación: fondo `Theme.cardColor`, encabezado con icono SVG, título, subtítulo y botón de cierre. Los archivos y acciones usan cards horizontales compactos para evitar espacios vacíos.

La tarjeta resumen está integrada al encabezado bajo el `AppBar`, dentro de una superficie `cardColor` con radios inferiores. El badge siempre representa el estado de la requisa. La información extensa del caso —estado del caso, delito, tipo, división, etapa, fecha y lugar del hecho, relato, fiscales asignados y contexto de la requisa— se abre desde **Ver detalle del caso** en el menú de tres puntos. El modal usa una columna en anchos compactos y dos columnas en anchos amplios. Los indicadores y acciones de sincronización se muestran junto al contenido de evidencias para mantener la cabecera compacta sin perder funcionalidad.

La información de la requisa se muestra inicialmente y puede ocultarse o restaurarse desde el botón de información del `AppBar`. El cambio usa `AnimatedSize` para liberar espacio vertical a las evidencias sin un salto brusco. Los botones circulares de consulta permanecen junto al texto con un espaciado corto; el área táctil conserva el tamaño accesible aunque el círculo visible sea compacto.

Importar archivos permite seleccionar múltiples elementos con el selector del sistema. Antes de confirmar se muestra un diálogo responsive con miniaturas, nombres y tamaño total. La sesión `FILE_CAST`/`SYSTEM_PICKER` se crea únicamente al confirmar ese preview; cancelar la selección no crea sesiones ni modifica la requisa. Al confirmar, el lote se cifra y se guarda en la outbox local. La aplicación intenta subirlo inmediatamente sin bloquear la navegación; WorkManager queda como respaldo persistente únicamente si todavía existen filas reintentables al terminar ese intento. De esta manera un mismo archivo no es reclamado a la vez por dos sincronizadores.

El bloque de sincronización que antecede a las evidencias muestra el archivo actual, su avance y el total de evidencias que todavía no fueron confirmadas. Distingue **Preparando seguridad** —registro del dispositivo, consulta de destinatarios y generación local de envolturas— de **Subiendo evidencia**, que comienza recién antes de crear la intención remota. Las envolturas X25519 para varios dispositivos autorizados se calculan en hasta seis isolates, dejando al menos un procesador fuera del lote, conservando todos los destinatarios y su orden sin bloquear el isolate visual ni procesarlos secuencialmente. Si una carga falla, conserva la evidencia local, muestra el error y habilita **Reintentar**. **Pausar carga** solo aparece durante una carga activa y desactiva el reintento automático de las filas no confirmadas sin borrar su FCE; una petición que el servidor ya haya aceptado se confirma localmente antes de pausar las siguientes para no duplicarla. Cada evidencia pendiente ofrece un menú de tres puntos junto al botón de vista previa con **Cargar** y **Eliminar**. **Cargar** reclama únicamente ese archivo y conserva pausado el resto; el contador global se recalcula desde la misma outbox al terminar. El estado de cada evidencia se deriva de la outbox local: `PENDING_UPLOAD` (pendiente/pausada), `UPLOADING` (subiendo), `ERROR` (error de subida) o `AVAILABLE` (sincronizada). El mirror muestra ese estado dentro del pie de cada miniatura y el detalle inmediatamente junto a su metadata, sin presentarlo como botón.

Los cambios de outbox actualizan las pantallas combinando el detalle remoto cacheado con SQLite; no ejecutan un nuevo `GET` por cada transición. Las lecturas se coalescen y repiten una última vez si llegó otro evento durante la combinación, de modo que una respuesta lenta no pueda sobrescribir `AVAILABLE` con un snapshot anterior. Al confirmar una o varias cargas, primero se refleja inmediatamente `AVAILABLE` desde SQLite y después se ejecuta una única reconciliación remota del detalle completo en segundo plano. Las tarjetas muestran miniaturas de imágenes locales —incluidas imágenes FCE descifradas temporalmente— y de videos locales mediante un JPEG derivado y cacheado. El extractor de video prueba varios instantes y modos de seek, reduce el frame durante la extracción cuando la API lo permite y usa `ThumbnailUtils` como respaldo para MP4 reproducibles que el extractor primario no logra muestrear. Las miniaturas conservan su estado por ID incluso al salir y volver al viewport, evitando descifrar o regenerar los primeros elementos al hacer scroll. Los videos disponibles únicamente mediante URL remota conservan el icono de tipo y el estado **En servidor** hasta que exista una copia local preparada; una miniatura ya cacheada puede reutilizarse sin volver a descifrar el video. La vista previa se abre únicamente desde el botón eye; tocar el resto del card no ejecuta ninguna acción. Las evidencias con `uploadStatus = PENDING_UPLOAD` o `ERROR` muestran además un botón de eliminación, con confirmación. Si la evidencia ya está registrada en el backend, el botón llama `DELETE /api/v1/requisitions/:id/evidences/:evidenceId` y elimina también la copia local si existe; si solo existe localmente, borra la copia y su operación de outbox. Una evidencia ya `AVAILABLE`/sincronizada o que está `UPLOADING` no muestra ese botón. Los temporales descifrados o descargados se eliminan al cerrar la vista previa. Las evidencias cifradas solo pueden previsualizarse en el dispositivo que conserva la envoltura de clave local.

El panel de evidencias compartido por mirror individual y múltiple se crea de forma diferida en su primera apertura y luego permanece montado fuera de pantalla al ocultarlo. Lista el inventario completo de la requisa, conserva miniaturas y preferencias entre aperturas repetidas dentro de la misma composición responsive y mantiene vivos los previews que salen temporalmente del viewport. Cada celda usa el ID estable de la evidencia y el builder puede resolver su índice nuevo: cuando una captura o grabación se inserta al inicio, Flutter reubica los elementos existentes sin desmontarlos y solo prepara el preview nuevo. Cuadrícula y lista comparten el mismo builder y el mismo subárbol de preview; alternar la geometría no vuelve a descifrar imágenes ni a extraer thumbnails de video. Un segundo botón iconográfico activa o retira una capa `BackdropFilter` sobre esos previews ya montados: tampoco modifica el archivo, su hash ni sus metadatos.

El card de disponibilidad offline separa el inventario completo de la requisa del lote ejecutado. Su resumen principal siempre muestra cuántas evidencias están disponibles localmente, el total elegible y cuántas faltan; abrir una sola evidencia con el botón eye no reemplaza ese total por el progreso `1 de 1`. Durante una sincronización general se muestra el nombre y avance del lote actual. Al terminar correctamente vuelve al resumen global; si hubo fallos, agrega como información secundaria el resultado del último intento y conserva **Ver detalle** con los errores recuperables.

El botón eye solicita únicamente la evidencia elegida. Si su descarga inmediata falla por red, timeout o indisponibilidad temporal, se registra un worker con el ID de esa evidencia y no con toda la requisa; el modal permite **Reintentar ahora** sin iniciar una segunda descarga directa en paralelo. El botón general **Sincronizar evidencias** sí mantiene alcance de requisa completa. Los trabajos de una misma requisa se serializan y cualquier intento manual cancela primero los workers pendientes de esa requisa para evitar competencia sobre el almacén cifrado local.

WorkManager se usa como respaldo después de un fallo recuperable del intento visible. Espera conectividad, aplica reintento exponencial y conserva el alcance original —una evidencia o la requisa completa— aunque la pantalla se cierre. La notificación de progreso desaparece al finalizar y se publica una notificación de resultado separada: **Evidencia disponible offline** para una selección o **Sincronización offline completada** para un lote. Tocar el resultado abre el detalle de la requisa; no se incluyen nombres, CUD ni datos personales en el texto del sistema.

La vista previa se abre como diálogo responsive con ancho máximo en pantallas grandes y márgenes visibles en móviles; el procesamiento del archivo conserva la misma preparación asíncrona y limpieza temporal. En Android, los controles existentes de `video_player` usan `video_player_media_kit` como backend basado en FFmpeg/libmpv para ampliar la compatibilidad de contenedores y códecs; el archivo sigue siendo local y temporal durante la vista previa.

Las grabaciones del mirror reutilizan sin recodificar las muestras H.264 entregadas por el encoder de scrcpy. Al pulsar grabar, la UI muestra **Preparando…** mientras espera el siguiente keyframe; scrcpy solicita un intervalo de un segundo y el contador comienza cuando esa primera muestra posterior al toque queda escrita, sin incluir un pre-roll anterior. Si un encoder ignora esa configuración, existe un timeout defensivo de 20 segundos. SPS/PPS se escriben como CSD Annex-B, el MP4 se construye primero como `.part`, recibe un marcador EOS para cerrar la duración del último frame y se valida con `MediaMetadataRetriever` antes de calcular hash, cifrar y registrar la evidencia. Un contenedor inválido falla en **Guardando…** y nunca entra a la outbox. Al salir de la pantalla de mirror se libera la textura, el decoder y la sesión nativa; al volver se crea una textura y un decoder nuevos, evitando mostrar el último frame congelado con el canal táctil todavía activo.

El gesto pull-to-refresh usa una consulta remota estricta y reemplaza el snapshot completo del detalle —cabecera, requisa, sesiones y evidencias— antes de volver a mezclar la outbox local. Si el backend no responde, conserva la vista anterior y presenta el error en vez de aparentar una actualización parcial desde caché.

- El botón flotante **+** abre un `ModalBottomSheet` con las acciones de adquisición disponibles mientras la requisa está en `DRAFT` o `IN_PROGRESS`: en Android incluye captura, transferencia e importación; en iOS conserva únicamente la importación local.
- **Captura de pantalla:** en Android crea o reutiliza una sesión `OPEN` en el backend con `ANDROID`/`USB_OTG_SCRCPY` y abre la conexión asociada a `requisitionId` y `sessionId`.
- **Transferencia de archivos:** en Android crea o reutiliza la misma sesión y continúa en `/requisitions/:requisitionId/acquisitions/:sessionId/transfer`. El selector permite ADB en objetivos Android y MTP/PTP de solo lectura cuando un iPad publica la interfaz USB `6/1/1`; el browser MTP usa únicamente los almacenamientos y objetos que el objetivo expone. El backend conserva temporalmente el método genérico `DEVICE_TRANSFER` y la sesión `ANDROID`/`USB_OTG_ADB` hasta acordar identificadores específicos para MTP.
- **Importar archivos:** en Android e iOS selecciona uno o varios archivos mediante el selector del sistema, muestra el preview de confirmación, crea o reutiliza una sesión de tipo `FILE_CAST`/`SYSTEM_PICKER` al aceptar, cifra y registra el lote en el outbox local, y muestra su progreso junto al contenido de evidencias.
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
lib/data/services/android_evidence_video_thumbnail_service.dart
lib/data/services/requisition_service.dart
lib/data/repositories/remote_requisition_detail_repository.dart
lib/data/repositories/remote_requisition_repository.dart
lib/domain/services/evidence_preview_service.dart
lib/domain/services/evidence_video_thumbnail_service.dart
lib/ui/features/requisitions/detail/
├── widgets/evidence_preview_sheet.dart
├── widgets/import_evidence_preview_dialog.dart
├── widgets/case_detail_sheet.dart
├── widgets/participant_role_dropdown.dart
├── widgets/participants_sheet.dart
├── view_models/requisition_detail_view_model.dart
└── views/
    └── requisition_detail_view.dart
lib/ui/core/widgets/evidence_thumbnail.dart
lib/ui/core/widgets/evidence_video_thumbnail.dart

lib/ui/features/acquisition/transfer/
├── view_models/file_transfer_view_model.dart
├── views/file_transfer_view.dart
└── widgets/file_transfer_widgets.dart
```

## Límite iOS

En iOS/iPadOS las acciones de captura por ADB/scrcpy y transferencia ADB no se muestran, porque el canal Android no existe. La pantalla de conexión conserva un fallback si se alcanza por una ruta externa, pero no inicia adquisición. Importar archivos permanece disponible mediante los selectores del sistema.

## Deuda

- El detalle, sesiones, vínculo a caso, gestión jerárquica de roles y evidencias remotas ya se leen/escriben contra el backend; la importación local usa selección múltiple, preview de confirmación, outbox cifrada y progreso de sincronización por lote. Falta validar el flujo probatorio completo en un entorno integrado.
- La galería y el preview remoto de evidencias sin cifrado ya están conectados. Las evidencias cifradas de otro dispositivo no se pueden previsualizar porque el backend no devuelve la envoltura de clave del dispositivo emisor.
- La compatibilidad de video depende de que el archivo no esté corrupto, protegido por DRM o use un códec propietario ausente del build nativo; `media_kit` amplía la cobertura, pero no convierte automáticamente archivos dañados.
- El cierre explícito de una sesión (`POST /api/v1/requisitions/:id/sessions/:sessionId/complete`) todavía no está conectado al ciclo de salida de las pantallas de adquisición.
- Transferencia ADB desde almacenamiento compartido está implementada como vertical local; falta validación física, persistencia probatoria y backend.
- ADB/scrcpy conserva alcance Android. La adquisición de un iPhone objetivo desde un inspector Android queda documentada como PoC futura separada: mirror por HDMI/UVC y archivos mediante `libimobiledevice`/AFC de solo lectura; no está implementada todavía.
