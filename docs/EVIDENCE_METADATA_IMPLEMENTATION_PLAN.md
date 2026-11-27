# Plan de implementación: procedencia y metadata de evidencias

Fecha: 27 de noviembre de 2026. Alcance: `file_cast` y `file-cast-back`.

## Objetivo y límites

Permitir que el operador consulte, desde **Información** en el menú de tres puntos de cada evidencia del detalle de requisa, qué archivo se obtuvo, de qué dispositivo o proveedor, cuándo lo adquirió File Cast y qué fechas declaró el origen. El backend conservará esos datos vinculados a la requisa, sesión y evidencia, también cuando la adquisición comenzó offline. Una fecha no disponible no se sustituye por la fecha actual ni por 1970.

Este plan conserva el protocolo ADB/scrcpy y el formato FCE. No presupone acceso a datos privados del objetivo, ni que MTP o ADB puedan informar cuándo se registró un archivo en la biblioteca del objetivo. La vista muestra la **procedencia declarada** de cada fecha; ninguna fecha extraída de un archivo se presenta como verificada por File Cast.

## Contrato de datos mínimo

El backend ya tiene `Evidence.acquisitionMethod`, `sourcePath`, `capturedAt`, `sourceCreatedAt`, `kind` y `metadata`; `File` contiene nombre, MIME, tamaños y hashes; `AcquisitionSession` contiene operador, inspector, plataforma, identificador/modelo/OS del objetivo, transporte, autorización y versión de herramienta. No duplicar estos datos en `metadata`.

`capturedAt` se define para **todos** los métodos como el instante UTC en que File Cast completó la adquisición y fijó el archivo local verificado. En grabaciones, es el cierre correcto del MP4; la fecha del hecho visible no se infiere del video. `sourceCreatedAt` solo recibe la creación que la fuente informó para su objeto, por ejemplo `MTP_DATE_CREATED`; no se rellena con `capturedAt`. Las evidencias históricas conservan el valor que ya tenían y se etiquetan en la UI como «fecha de registro en File Cast» cuando no se puede acreditar un instante nativo más preciso.

`metadata` versión 1:

```json
{
  "version": 1,
  "sourceSessionId": null,
  "sourceDeviceName": null,
  "inspectorDeviceName": null,
  "recordingStartedAt": null,
  "sourceCreatedAtSource": null,
  "sourceModifiedAt": null,
  "registeredOnDeviceAt": null,
  "registeredOnDeviceAtSource": null,
  "contentCapturedAt": null,
  "contentCapturedAtSource": null
}
```

Los campos opcionales nulos se omiten al serializar. Las fechas presentes son ISO 8601 UTC. `contentCapturedAt` se guarda solo si el contenido incluye un offset/zona que permita convertirlo sin suponer la zona; de otro modo se omite y los bytes originales permanecen en el FCE. `registeredOnDeviceAt` solo se guarda cuando se consultó directamente una biblioteca identificada y debe mostrarse como fecha de **esa biblioteca**: una fototeca del inspector no demuestra que el archivo estuviera registrado en el teléfono investigado.

| Campo | Fuente válida | Uso |
|---|---|---|
| `sourceSessionId` | Registro nativo de mirror múltiple | Identifica el objetivo concreto dentro de una sesión con varios. Ausente en sesiones singulares. |
| `sourceDeviceName` | Nombre que el adaptador mostró durante la adquisición | Snapshot legible del objetivo en mirror y transferencias; puede ser ambiguo y no equivale a un número de serie. |
| `inspectorDeviceName` | Modelo que informa el sistema operativo del equipo que ejecuta File Cast | Identifica el equipo inspector en importaciones, mirror y transferencias; en iOS puede ser un identificador de hardware en vez del nombre comercial. |
| `recordingStartedAt` | Primer fotograma conservado del recorder | Inicio UTC de una grabación de mirror; `capturedAt` indica su cierre. Ausente en capturas y archivos importados. |
| `sourceCreatedAtSource` | `MTP_DATE_CREATED` u otra API que entregue creación de objeto | Explica la columna existente `sourceCreatedAt`. |
| `sourceModifiedAt` | ADB Sync `STAT`, MTP `dateModified`, proveedor de documentos/fototeca | Última modificación reportada en origen; no equivale a captura ni registro. |
| `registeredOnDeviceAt` y `registeredOnDeviceAtSource` | MediaStore `DATE_ADDED`, PhotoKit `addedDate` u otra biblioteca identificada | Fecha de incorporación a esa biblioteca. ADB Sync y MTP solos dejan ambos ausentes. |
| `contentCapturedAt` y `contentCapturedAtSource` | EXIF `DateTimeOriginal`, fecha de contenedor o PhotoKit `creationDate`, con zona confiable | Fecha declarada de producción del contenido; nunca reemplaza `capturedAt`. |

### Ejemplos de valores

| Método | Columnas de evidencia | `metadata` adicional |
|---|---|---|
| Captura por mirror | `SCREEN_CAPTURE`, `capturedAt` nativo; `sourcePath` y `sourceCreatedAt` nulos | `{"version":1}`; en mirror múltiple, `sourceSessionId`. |
| Grabación por mirror | `SCREEN_RECORDING`, `capturedAt` al finalizar MP4 | `recordingStartedAt` del primer fotograma conservado y, en multi, `sourceSessionId`; fecha del contenido en pantalla no inferida. |
| Transferencia ADB | `DEVICE_TRANSFER`, `sourcePath=/sdcard/...`, `sourceCreatedAt=null` | `sourceModifiedAt` de `STAT`; `contentCapturedAt` solo si el archivo lo declara con zona confiable. |
| Transferencia MTP | `DEVICE_TRANSFER`, `sourcePath=mtp:storage:handle`, `sourceCreatedAt` si MTP lo informa | `sourceCreatedAtSource=MTP_DATE_CREATED`, `sourceModifiedAt`; no atribuir `registeredOnDeviceAt` a MTP. |
| Importación de archivos | `IMPORTED_FILE`, `capturedAt` tras copia; ruta de origen solo si el proveedor la entrega legítimamente | `sourceModifiedAt` del proveedor; otros campos solo si están disponibles antes de crear la copia temporal. |
| Importación de fototeca | `IMPORTED_FILE` | Fecha de biblioteca y fecha de contenido si PhotoKit/MediaStore las entrega; identificar si la biblioteca pertenece al inspector. |

## Trabajo en `file-cast-back`

1. **Contrato tipado.** Reemplazar la validación genérica `@IsObject()` de `CreateEvidenceIntentDto.metadata` por un DTO versión 1 con claves permitidas, fechas UTC válidas, pares fecha/fuente coherentes, longitud acotada y rechazo de campos desconocidos. Aceptar `metadata=null`/ausente para evidencias anteriores. Validar `sourceCreatedAtSource` solo si `sourceCreatedAt` existe. No usar `sourceCreatedAt` como sustituto de `registeredOnDeviceAt`.
2. **Identidad de sesión.** Aprovechar las columnas existentes de `AcquisitionSession` para recibir `sourceDeviceId`, `sourceModel`, `sourceOsVersion`, `deviceId`, `toolBuild` y `adapterVersion` que el móvil aún no envía. Para mirror múltiple, crear una relación `acquisition_sources` con `(sessionId, sourceSessionId)` único y la identidad de cada objetivo; validar que el `sourceSessionId` enviado en `metadata` pertenece a la sesión. Esto requiere migración Prisma. No guardar el identificador USB temporal como identidad permanente del objetivo.
3. **Lectura.** Añadir `sourceCreatedAt` y `metadata` al modelo `EvidenceSummary` y al mapeo Prisma. Exponer en el detalle los campos de sesión necesarios para identificar el objetivo; para mirror múltiple, devolver la fuente asociada. Mantener los mismos controles de acceso por requisa. Los registros anteriores devuelven campos nulos y metadata ausente.
4. **Inmutabilidad e idempotencia.** Una intención con el mismo `evidenceId` no puede reaparecer con distinta metadata o `sourceCreatedAt` como si fuera el mismo registro. Comparar una representación canónica de los campos probatorios en el replay idempotente. Incluir su hash en el evento de custodia de creación, junto con el hash del archivo. Una corrección posterior debe ser una adenda/evento, no sobrescribir silenciosamente el valor original.
5. **Seguridad.** No introducir GPS, IMEI, EXIF completo ni seriales completos en `metadata`. Proteger el acceso a `sourcePath`, nombre original e identificadores de dispositivo ya existentes; excluirlos de logs. Cifrar la base y sus respaldos antes del piloto. Si la política exige que administradores de base no lean esos valores, agregar cifrado por campo con KMS y migración específica antes de producción; el JSONB actual queda en claro para el backend aunque el FCE esté cifrado. Documentar esa decisión institucional antes de cerrar la etapa de seguridad.
6. **Documentación y verificación backend.** Actualizar Swagger y documentación de requisas. Cubrir DTO válido/inválido, `null`, reintento con metadata diferente, lectura autorizada, fuente múltiple inexistente y registros históricos.

La columna `Evidence.metadata` ya existe; **la metadata mínima por sí sola no requiere migración de evidencias**. La tabla de fuentes múltiples y cualquier cifrado por campo sí requieren migraciones versionadas. No editar `src/generated` manualmente.

## Trabajo en `file_cast`: adquisición y sincronización

1. **Modelos y persistencia local.** Crear un snapshot de metadata versión 1 inmutable en dominio y DTO de API; añadir `source_created_at` y `metadata_json` a `evidencias_locales` mediante migración SQLCipher idempotente. Persistir junto con evidencia y outbox para que el proceso pueda reiniciarse sin perder procedencia. Guardar el mapa local `sourceSessionId → dispositivo` para mirror múltiple y sincronizarlo antes de sus evidencias. Los registros previos se leen sin metadata.
2. **Mirror.** Tomar `capturedAt` del instante nativo de cierre/verificación del PNG o MP4, no de `DateTime.now()` cuando Dart recibe la respuesta. Para MP4, guardar además `recordingStartedAt` al primer fotograma efectivamente escrito. Adjuntar `sourceSessionId` a cada captura/grabación múltiple y mantener su asociación con el USB concreto aunque cambie el foco visual. No añadir EXIF o «fecha de creación en objetivo» a una captura de pantalla.
3. **ADB Sync.** Propagar `modifiedAtSeconds` del `STAT` usado antes de `RECV` desde `AdbSyncClient` y `UsbPlugin` hasta `CapturedEvidence`; convertir segundos UTC y descartar valores inválidos. Mantener `sourceCreatedAt` y `registeredOnDeviceAt` ausentes. No cambiar el protocolo Sync v1 ni añadir escritura en el objetivo.
4. **MTP/PTP.** Propagar `MtpObjectInfo.dateCreated` y `dateModified` desde la consulta inmediatamente anterior a `importFile`; valores ausentes/cero quedan nulos. Poner `sourceCreatedAtSource=MTP_DATE_CREATED` únicamente cuando exista `sourceCreatedAt`. Conservar la referencia MTP en `sourcePath`, sin describirla como ruta permanente.
5. **Importación.** Consultar fecha de modificación y, si se puede identificar la biblioteca, fecha de incorporación **antes** de copiar a un temporal. En Android, el picker actual entrega principalmente una copia local; evaluar el URI/proveedor nativo para obtener fechas sin confundirlas con las del temporal. En iOS, extender el puente `PHPicker`/PhotoKit solo cuando `assetIdentifier` y permisos permitan leer `addedDate`/`creationDate`; si no, omitir. No pedir permisos más amplios solo para rellenar un campo opcional.
6. **Fecha interna del contenido.** Extraer `contentCapturedAt` de los bytes adquiridos sin modificarlos; comenzar por imágenes EXIF y formatos multimedia soportados. Aceptar UTC solo con offset confiable. Un fallo del extractor no bloquea la evidencia ni inventa fechas. El extractor trabaja en servicio, fuera de la View.
7. **Subida y recuperación.** Enviar `sourceCreatedAt` y `metadata` en `evidence-intents` desde la fila local, con el mismo `evidenceId` y datos estables en cada reintento. Mapearlos desde `GET /requisitions/:id` al dominio y al snapshot offline. En `RequisitionDetailViewModel`, combinar la evidencia remota con la local pendiente sin reemplazar metadata más completa por una respuesta antigua.

La vertical conserva `View → ViewModel → Repository → Service`; `provider` registra las dependencias nuevas. Los modelos nuevos siguen la regla Freezed del repositorio; no editar archivos generados manualmente.

## Pantalla de Información en detalle de requisa

1. Añadir **Información** con icono `info_outline` al `_EvidenceActionsMenu` de cada tarjeta. Debe aparecer en las tres superficies que reutilizan el menú: secciones del detalle, **Ver todo** y **Evidencias pendientes**. Será una acción de solo lectura, disponible también mientras la evidencia se sube; las acciones mutantes pueden seguir deshabilitadas durante la carga.
2. Abrir una hoja inferior con el estilo de los modales existentes. Pasar la evidencia seleccionada y su sesión/fuente al widget; la hoja no consulta providers ni ejecuta HTTP. El ViewModel expone un snapshot de presentación derivado del repositorio. Si el detalle remoto carece de datos pero existe una fila local, usar esta última sin bloquear la apertura.
3. Mostrar solo datos útiles, con etiquetas comprensibles:
   - **Archivo:** nombre original/visible, tipo, tamaño, estado de sincronización, ID de evidencia.
   - **Origen:** método, dispositivo objetivo identificado y transporte; ruta o referencia MTP si existe. Para importación desde la fototeca del inspector, decirlo explícitamente.
   - **Fechas:** «Adquirida por File Cast» (`capturedAt`); para MP4 de mirror, «Inicio de grabación»; «Creación informada por el origen» (`sourceCreatedAt` + fuente); «Última modificación en origen»; «Añadida a la biblioteca de [dispositivo]»; «Captura declarada dentro del archivo». Cada fila opcional ausente muestra **No disponible**, sin 1970.
   - **Integridad:** SHA-256 del contenido original y del FCE, tamaño original y estado de verificación, tomados de los campos existentes; permitir copiar hashes completos sin truncarlos en la copia.
4. Conservar el lenguaje visual y el tema. En compact, hoja desplazable y segura frente a insets/altura menor a 480; en expanded, contenido centrado con ancho legible y secciones que puedan distribuirse en dos columnas según `LayoutBuilder`. Soportar escalado de texto, teclado, mouse y targets de 48 dp. No crear una ruta nueva: es un modal dentro de `/requisitions/:requisitionId`.
5. Tratar estados: evidencia local pendiente, remota, offline cacheada, metadata parcial y registro histórico. El botón siempre abre; los campos faltantes se explican sin aparentar que la adquisición falló. Al abrir desde **Ver todo**, preservar el contexto para poder volver al listado de esa categoría.

## Orden de implementación y criterios de aceptación

| Etapa | Dependencia | Resultado comprobable |
|---|---|
| 1. Contrato backend y lectura | Ninguna | DTO versión 1, respuestas con metadata/fecha, compatibilidad histórica. |
| 2. Fuente múltiple | Etapa 1 | Cada evidencia multi se resuelve a un objetivo concreto; fuente inexistente se rechaza. |
| 3. Modelo local y adaptadores | Contrato fijado | ADB/MTP/import/mirror conservan solo fechas realmente disponibles, también offline. |
| 4. Sincronización | Etapas 1–3 | Reintentos no cambian metadata; backend devuelve la misma ficha tras subir. |
| 5. Menú y hoja Información | Etapas 1 y 3 | Misma ficha en detalle, Ver todo y pendientes; estados parciales visibles. |
| 6. Validación integrada | Todas | Fixtures con fechas diferentes, reloj incorrecto, MTP sin fechas, EXIF sin offset, dos mirrors y recuperación offline. |

El backend ejecutará sus pruebas, migraciones y validadores conforme a su `AGENTS.md` cuando se implemente. Para Flutter, el propietario reserva `flutter test`, `flutter analyze`, `flutter run`, `flutter build`, compilaciones nativas y generadores según el `AGENTS.md` de File Cast. La aceptación física requiere comprobar ADB y MTP en hardware real; las fechas declaradas por el objetivo se contrastarán con fixtures conocidos.

## Estado de esta implementación

Se implementaron la persistencia y sincronización de la metadata mínima, las fechas reportadas por ADB/MTP, el inicio y cierre de mirror, la lectura backend y la ficha de Información. Para mirror múltiple se guarda `sourceSessionId` junto con un snapshot `sourceDeviceName` en cada evidencia; el backend registra su asociación en `fuentes_adquisicion` al recibir la primera evidencia y rechaza otro nombre para la misma fuente. La correspondencia física con el objetivo requiere comprobación en hardware real. En iOS, PhotoKit solo expone `addedDate` desde iOS 26 y con permiso de fototeca; `creationDate` se registra cuando el activo es accesible. Los pickers de archivos y la fototeca Android no exponen en este flujo un URI de origen fiable para fechas de biblioteca; esos campos quedan ausentes. La extracción EXIF/medios desde bytes y el cifrado por campo de columnas sensibles del backend también quedan pendientes de una etapa específica.

## Archivos de partida

Backend: `prisma/schema.prisma`, `src/modules/requisitions/presentation/http/dto/evidence.dto.ts`, `src/modules/requisitions/domain/requisition.ts`, `src/modules/requisitions/requisitions.service.ts`, `src/modules/requisitions/infrastructure/persistence/prisma-requisitions.repository.ts`.

App: `android/app/src/main/kotlin/com/fiscalia/file_cast/sync/AdbSyncClient.kt`, `android/app/src/main/kotlin/com/fiscalia/file_cast/usb/MtpTransferBridge.kt`, `lib/data/services/android_acquisition_platform_service.dart`, `lib/data/services/evidence_picker_service.dart`, `ios/Runner/AppDelegate.swift`, `lib/data/services/local_evidence_database_service.dart`, `lib/data/services/evidence_sync_service.dart`, `lib/data/services/requisition_detail_service.dart`, `lib/domain/models/requisition_detail.dart`, `lib/ui/features/requisitions/detail/view_models/requisition_detail_view_model.dart` y `lib/ui/features/requisitions/detail/views/requisition_detail_view.dart`.
