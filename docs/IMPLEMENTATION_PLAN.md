# Plan de implementación de File Cast

El flujo de cifrado local y outbox está documentado en
[CLIENT_SIDE_ENCRYPTION.md](CLIENT_SIDE_ENCRYPTION.md). La validación Flutter
debe ejecutarse con el SDK fijado por el proyecto; durante esta tarea se agregó
la prueba unitaria del servicio, pero no se ejecutan comandos Flutter por las
restricciones operativas del repositorio.

Este documento convierte el objetivo del producto y los tres mockups en un plan técnico. Debe leerse junto con [PROJECT_STATUS_AND_FEASIBILITY.md](PROJECT_STATUS_AND_FEASIBILITY.md), [HARDWARE_REQUIREMENTS.md](HARDWARE_REQUIREMENTS.md), [IOS_USB_LIBIMOBILEDEVICE_PLAN.md](IOS_USB_LIBIMOBILEDEVICE_PLAN.md), `AGENTS.md` y las skills Flutter del repositorio. Para trabajar una vista en otra sesión puede usarse [SINGLE_VIEW_REFACTOR_PROMPT.md](SINGLE_VIEW_REFACTOR_PROMPT.md).

La matriz y el plan detallado para recibir objetivos Android/iPhone mediante
salida HDMI y capturadora UVC están en
[HDMI_UVC_VIDEO_CAPTURE_IMPLEMENTATION_PLAN.md](HDMI_UVC_VIDEO_CAPTURE_IMPLEMENTATION_PLAN.md).
Las conexiones físicas de Mirror, Transferencia, Capturadora e Importar están en
[HDMI_UVC_CABLE_CONNECTION_GUIDE.md](HDMI_UVC_CABLE_CONNECTION_GUIDE.md).
El soporte multisesión dinámico de N fuentes de video, con ORICO ADB 1/2/3,
mezcla obligatoria 2 ADB + 1 UVC y un hub de seis puertos como ampliación
4/5/6, está en
[ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md](ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md).

> Límite de ejecución: las pruebas, compilaciones y validadores mencionados en este plan son criterios de aceptación a cargo del propietario o de una tarea futura que los autorice expresamente. Las sesiones de reestructuración deben limitarse al código y a la inspección del diff.

## Objetivo del producto

File Cast permitirá que un operador autorizado:

1. inicie sesión;
2. liste, filtre, cree y continúe requisas;
3. abra el detalle de una requisa y consulte sus evidencias;
4. cree una sesión de adquisición ligada a esa requisa;
5. conecte un dispositivo objetivo compatible;
6. vea su pantalla y, donde la plataforma lo permita, interactúe con ella;
7. capture una imagen, inicie/detenga una grabación o importe archivos seleccionados;
8. almacene cada evidencia localmente como FCE cifrado con integridad verificable;
9. sincronice la outbox cifrada al servicio cuando haya conectividad;
10. finalice y selle la requisa sin perder el historial de custodia.

En el detalle, la cabecera fija debe centralizar el contexto de caso/persona,
sujetos, participantes y ubicación. Una requisa creada por persona puede
vincularse posteriormente a un CUD mediante la búsqueda del ecosistema; esa
acción actualiza el vínculo actual y su snapshot, y queda registrada por el
backend como evento `CASE_LINKED`.

No forma parte del alcance base: bypass de bloqueo, explotación, root/jailbreak, extracción física, acceso a datos privados de terceros ni control general de iOS desde otro móvil.

## Decisiones de producto recomendadas

### 1. Android primero

Completar un vertical Android funcional antes de abrir el desarrollo nativo iOS. El vertical debe cubrir requisa -> conexión -> captura/archivo -> hash -> galería -> subida -> sellado.

### 2. Capacidades, no promesas por nombre de plataforma

Cada conexión publicará capacidades en tiempo de ejecución:

```text
canMirror
canControl
canCaptureScreenshot
canRecordScreen
canBrowseSharedFiles
canBrowseIosAfc
canBrowseIosFileSharingApps
canCreateIosLogicalBackup
canCaptureAudio
requiresUnlock
requiresTrust
```

La UI habilitará acciones según estas capacidades. Así iOS no necesita simular funciones que el sistema no ofrece.

### 3. Ruta iOS sin companion ni computadora

La decisión de producto vigente separa dos canales:

- **Mirror:** salida de video del iPhone -> HDMI -> capturadora UVC -> inspector.
- **Archivos:** iPhone desbloqueado y confiado -> USB OTG -> inspector Android,
  mediante una futura PoC con `libimobiledevice`, usbmux, lockdownd y AFC.

No se promete acceso completo al sistema de archivos, control táctil, bypass,
jailbreak ni operación simultánea de video y datos por el único puerto del
iPhone. La implementación permanece diferida hasta concluir Android y está
definida en [IOS_USB_LIBIMOBILEDEVICE_PLAN.md](IOS_USB_LIBIMOBILEDEVICE_PLAN.md).

### 4. Evidencia inmutable; anotaciones separadas

Nunca editar el archivo original. Recortes, compresiones, thumbnails, OCR o anotaciones crean derivados con su propio hash y referencia al original.

### 5. Offline-first y cifrado local

Crear y consultar requisas asignadas, capturar evidencia y mantener el ledger
debe funcionar sin internet. Las evidencias se cifran en el dispositivo, se
guardan en SQLite SQLCipher y la sincronización consume una outbox idempotente y
reanudable. El backend nunca recibe el plano.

## Arquitectura objetivo

Se aplicará MVVM con UI, datos y dominio opcional. Las Views solo renderizan y envían intenciones; los ViewModels exponen estados inmutables y comandos; los repositorios son fuente de verdad; los servicios envuelven HTTP, base local, archivos y canales nativos.

```text
View
  -> ViewModel / Command
      -> Use case (cuando combina reglas/repositorios)
          -> Repository interface
              -> Repository implementation
                  -> API / DB / encrypted files / native platform service
```

Los casos de uso sí se justifican en adquisición porque crear una evidencia combina sesión, archivo, hashing, almacenamiento, ledger, thumbnail y outbox.

### Estructura propuesta

```text
lib/
├── data/
│   ├── models/                    # DTO de API/base local
│   ├── repositories/              # Implementaciones
│   └── services/
│       ├── api/
│       ├── database/
│       ├── evidence_files/
│       ├── platform/              # MethodChannel/Pigeon, sin estado UI
│       └── sync/
├── domain/
│   ├── models/                    # Modelos inmutables
│   ├── repositories/              # Contratos
│   └── use_cases/
│       ├── acquisition/
│       ├── evidence/
│       ├── requisitions/
│       └── sync/
└── ui/
    ├── core/
    │   ├── adaptive/
    │   ├── theme/
    │   └── widgets/
    └── features/
        ├── auth/
        ├── requisitions/
        │   ├── list/
        │   ├── create/
        │   └── detail/
        ├── acquisition/
        │   ├── connect/
        │   ├── mirror/
        │   └── transfer/
        ├── evidence/
        └── settings/
```

La UI activa vive en `lib/ui/`; `lib/presentation/` y su infraestructura responsive heredada fueron retirados. Toda feature nueva entra directamente con la estructura objetivo.

### Límites del código nativo

Separar el plugin Android monolítico en componentes con ciclo de vida explícito:

```text
android/.../acquisition/
├── AcquisitionPlugin.kt           # API hacia Flutter
├── AcquisitionSession.kt          # estado de una conexión
├── usb/UsbDeviceService.kt
├── adb/AdbConnection.kt
├── adb/AdbStreamMux.kt
├── sync/AdbSyncClient.kt           # push, list, stat, pull
├── mirror/ScrcpySession.kt
├── mirror/VideoDecoder.kt
├── capture/ScreenshotCapture.kt
├── capture/ScreenRecorder.kt
└── diagnostics/AcquisitionLogger.kt
```

El bridge debe usar DTO tipados y versionados, preferentemente generados, en vez de mapas/strings libres. Cada método debe llevar `sessionId`; ningún singleton global debe aceptar acciones de otra requisa.

### Navegación objetivo

Usar una única configuración declarativa con `MaterialApp.router` y `go_router`, ubicada en `lib/ui/core/navigation/`. Las rutas deben expresar la jerarquía de negocio (`requisitions/:requisitionId/acquisition/:sessionId`) y recibir IDs persistibles por path parameters.

No crear rutas nuevas con `Navigator.push`/`MaterialPageRoute` ni pasar contratos con `Map<String, dynamic>`. Handles efímeros como `textureId` pueden viajar únicamente en un argumento tipado y siempre acompañados por los IDs de requisa/sesión que permitan recuperar o mostrar un fallback. Los redirects de autenticación viven en el router y observan un estado de sesión, no ejecutan HTTP.

Las reglas obligatorias de navegación están en `AGENTS.md` y en la skill `flutter-setup-declarative-routing`.

## Modelo de dominio mínimo

### Requisition

```text
id, cud?, subject?, description, location, startedAtUtc,
status, assignedOperatorId, createdAtUtc, updatedAtUtc,
serverVersion, finalizedAtUtc?, sealedManifestHash?
```

Estados recomendados:

```text
draft -> inProgress -> finalizing -> finalized
                       \-> syncFailed -> finalizing
```

Una requisa finalizada no vuelve a edición. Una corrección se agrega como evento/adenda.

### AcquisitionSession

```text
id, requisitionId, operatorId, sourcePlatform, sourceDeviceId,
sourceModel, sourceOsVersion, transport, startedAtUtc, endedAtUtc?,
capabilities, authorizationReference, status, toolBuild, adapterVersion
```

### Evidence

```text
id, requisitionId, acquisitionSessionId, kind,
originalFileName?, localRelativePath, mimeType, byteLength,
sha256, capturedAtUtc, sourceCreatedAtUtc?, acquisitionMethod,
sourcePath?, derivedFromEvidenceId?, syncState, serverId?, metadata
```

Tipos iniciales: `screenCapture`, `screenRecording`, `importedImage`, `importedVideo`, `importedDocument`, `sessionLog`, `manifest`.

### CustodyEvent

```text
id, evidenceId?, requisitionId, sessionId?, sequence,
eventType, actorId, occurredAtUtc, monotonicOffset,
deviceId, payloadHash, previousEventHash, eventHash, signature?
```

La cadena `previousEventHash -> eventHash` hace evidentes alteraciones. El servidor debe volver a verificar todos los hashes; SHA-256 aporta integridad, no confidencialidad. Los archivos locales también deben cifrarse.

## Contratos principales

### Repositorios

- `AuthRepository`
- `RequisitionRepository`
- `AcquisitionRepository`
- `EvidenceRepository`
- `CustodyLedgerRepository`
- `SyncRepository`
- `SettingsRepository`

### Servicios

- `AuthApiService`, `RequisitionApiService`, `EvidenceUploadApiService`
- `LocalDatabaseService`
- `EncryptedEvidenceFileService`
- `HashService`
- `AndroidAcquisitionPlatformService`
- `IosUsbAcquisitionPlatformService` (PoC futura en inspector Android)
- `UvcVideoCapturePlatformService` (mirror iPhone, futuro)
- `ConnectivityService`
- `BackgroundSyncService`

### Casos de uso

- `CreateRequisition`
- `StartAcquisitionSession`
- `ConnectSourceDevice`
- `CaptureScreenEvidence`
- `StartScreenRecording` / `StopScreenRecording`
- `ImportSourceFiles`
- `RegisterEvidenceAtomically`
- `SyncPendingEvidence`
- `FinalizeAndSealRequisition`

`RegisterEvidenceAtomically` debe escribir a temporal, calcular hash en streaming, hacer `fsync`/rename atómico, insertar evidencia y ledger en transacción, generar thumbnail como derivado y crear el item del outbox.

## Estados MVVM

Cada ViewModel expondrá un snapshot inmutable. Ejemplos:

```text
RequisitionListState
  items, query, filters, page, isLoading, isRefreshing, error

RequisitionDetailState
  requisition, evidence, connectionSummary, syncSummary,
  availableActions, isFinalizing, error

AcquisitionState
  session, devices, connectionPhase, capabilities,
  mirror, recording, transfers, availableSpace, error
```

Los comandos (`load`, `refresh`, `create`, `connect`, `capture`, `startRecording`, `stopRecording`, `importFiles`, `finalize`) controlan concurrencia y exponen resultado. Un tap repetido no puede abrir dos conexiones ni finalizar dos veces.

## Pipeline de evidencia

```text
Acción del operador
  -> verificar requisa/sesión/capacidad/espacio
  -> adquirir bytes a archivo temporal
  -> calcular SHA-256 mientras se escribe
  -> cerrar y verificar tamaño/hash
  -> mover al almacén cifrado
  -> transacción: Evidence + CustodyEvent + Outbox
  -> thumbnail/preview derivado
  -> actualizar ViewModel
  -> subir por chunks cuando haya red
  -> servidor verifica hash y confirma receipt
  -> evento de custodia "uploaded/verified"
```

No enviar frames de video por `MethodChannel`. El lado nativo escribe/multiplexa a archivo y solo reporta progreso/estado a Flutter.

## Implementación Android

### Captura de pantalla

Ruta recomendada:

1. abrir un servicio ADB binario (`exec:screencap -p` o equivalente compatible);
2. transmitir los bytes PNG directamente a un archivo temporal del inspector;
3. no convertir a `String` ni pasar el archivo completo por `MethodChannel`;
4. validar firma PNG, tamaño y límites;
5. registrar la evidencia atómicamente;
6. mostrar el thumbnail en el panel de la requisa.

Como fallback, capturar un frame del pipeline de video implica rediseñar la superficie de decodificación; no debe asumirse que un `Texture` Flutter se puede convertir fielmente a imagen.

### Grabación

El stream H.264 de scrcpy debe alimentar en paralelo:

- el decoder para vista en vivo;
- un recorder nativo con `MediaMuxer` para MP4.

El recorder espera SPS/PPS/config, crea el track, usa PTS monotónicos, marca keyframes, rota segmentos ante límites y finaliza el contenedor aun si se desconecta el cable. El botón muestra `starting`, `recording`, `stopping`, duración y espacio. El archivo no se registra como evidencia hasta que el muxer cierre y el hash se verifique.

### Transferencia objetivo -> inspector

Estado al 8 de septiembre de 2026: primera vertical Android implementada para almacenamiento compartido. Usa ADB Sync v1 `LIST`/`STAT`/`RECV`, escritura nativa por streaming a `.part`, `fsync`, rename en el mismo directorio, SHA-256, selección múltiple secuencial, progreso y cancelación. Está ligada a `requisitionId`/`sessionId` y reutiliza una conexión ADB activa sin obligar a iniciar scrcpy. Continúan pendientes la validación física, deduplicación por hash, persistencia transaccional/ledger y una alternativa companion.

Implementar ADB sync completo:

- `STAT`/`LIST` para metadatos;
- `RECV`/`DATA`/`DONE` para pull;
- cancelación, progreso, timeout y hash;
- nombres seguros y protección contra path traversal;
- límites de tamaño/cuota;
- selección múltiple y reanudación si el protocolo lo permite.

Dos UX posibles:

- **Galería accesible por ADB:** iniciar con DCIM/Pictures/Movies/Download y permitir explorar opcionalmente `/sdcard` completo dentro de lo que el usuario `shell` pueda leer. No implica acceso a datos privados de apps.
- **App compañera Android:** usar Photo Picker/Storage Access Framework en el objetivo para que la persona elija explícitamente; luego transferir por un canal autenticado. Es la opción más consistente con scoped storage y consentimiento.

### Robustecimiento del mirror/control

- buffer circular/bounded queue y métricas de frames descartados;
- buffer por stream para lecturas exactas sin perder excedentes;
- sesión/estado único y cleanup idempotente;
- rotación dinámica y transformación de coordenadas probada;
- errores propagados al ViewModel;
- bitrate, resolución y FPS configurables para equipos lentos;
- validación por Android/API/fabricante;
- actualización controlada de scrcpy después de fijar una batería de pruebas.

## Implementación iOS

### Mirror por HDMI/UVC

1. Obtener la salida HDMI mediante el adaptador correspondiente a Lightning o
   USB-C.
2. Recibirla con una capturadora UVC homologada.
3. Implementar la captura UVC en el inspector sin mezclarla con ADB/scrcpy.
4. Registrar modelo de adaptador/capturadora, resolución, FPS y limitaciones en
   la sesión.
5. Guardar capturas y grabaciones mediante el pipeline probatorio común.

Este canal solo transporta imagen/audio. No controla el iPhone ni transfiere sus
archivos y puede recibir una pantalla negra ante contenido protegido.

### Transferencia USB con libimobiledevice

1. Usar el inspector Android como USB Host, sin Mac/PC ni app en el target.
2. Obtener permiso con `UsbManager` y adaptar el descriptor autorizado a la capa
   nativa.
3. Implementar usbmux, lockdownd y pairing/trust sin root.
4. Almacenar los pair records cifrados mediante Android Keystore.
5. Exponer AFC general y House Arrest únicamente en modo lectura.
6. Reutilizar preview, selección, `.part`, hash, `fsync` y registro de evidencia.
7. Evaluar MobileBackup2 en una fase opcional y con ADR separado.

El alcance, arquitectura, fases, gates, riesgos y matriz están especificados en
[IOS_USB_LIBIMOBILEDEVICE_PLAN.md](IOS_USB_LIBIMOBILEDEVICE_PLAN.md). La PoC no
comenzará hasta cerrar el vertical Android actual.

## API y sincronización

Endpoints lógicos mínimos:

```text
POST   /auth/session
GET    /requisitions?cursor=&status=&from=&to=&query=
POST   /requisitions
GET    /requisitions/{id}
PATCH  /requisitions/{id}                 # con version/ETag
POST   /requisitions/{id}/acquisition-sessions
POST   /evidence/uploads                   # inicia upload reanudable
PUT    /evidence/uploads/{id}/parts/{n}
POST   /evidence/uploads/{id}/complete     # servidor verifica hash
POST   /requisitions/{id}/finalize         # sella manifiesto
GET    /sync/changes?cursor=
```

Requisitos:

- idempotency key en creates/finalize;
- cursor y versionado, no paginación por índice mutable;
- chunks reintentables y verificación final;
- códigos de error estables;
- refresh token protegido;
- autorización por rol/requisa;
- auditoría server-side append-only;
- retención y borrado según política aprobada.

## Mapeo de los mockups

### Mockup 1 — adquisición y detalle

- panel principal: dispositivo, transporte, mirror y controles;
- panel de soporte: cabecera de requisa, custodia, vínculo CUD y grid de evidencias;
- acción primaria inferior: finalizar/sellar;
- en ancho compacto el panel de evidencia pasa a una hoja/pestaña, no se comprime al lado del mirror;
- botones foto/grabación forman una barra persistente, pero nunca tapan el área táctil del dispositivo.

### Mockup 2 — listado

- búsqueda, estado, fecha, refresh/sync y crear;
- teléfono: cards con datos esenciales;
- ancho expandido: tabla/lista densa con columnas;
- paginación/cursor real y estados vacío/error/offline.

### Mockup 3 — crear requisa

- teléfono/altura compacta: página full-screen desplazable con CTA inferior seguro;
- tablet: dialog centrado y limitado de ancho;
- elegir CUD y registrar persona son estados del ViewModel, no dos formularios independientes;
- GPS, fecha y almacenamiento offline deben mostrar procedencia y permisos.
- Estado actual: implementado como vertical UI/MVVM inicial en [modules/requisitions_create.md](modules/requisitions_create.md), con registro simulado y mapa/GPS nativo pendientes.

## Fases de entrega

### Fase 0 — alcance, laboratorio y toolchain

- Flutter 3.44/Dart 3.12 fijados localmente mediante `.fvmrc`; falta replicarlo
  en CI;
- definir versiones mínimas y matriz de dispositivos;
- aprobar política legal/consentimiento/custodia;
- crear set de archivos/pantallas conocidos para validación;
- registrar licencia y hash del servidor scrcpy;
- eliminar promesas de paridad iOS no posibles.

Salida: build reproducible, ADR de plataformas, matriz y protocolo de prueba aprobados.

### Fase 1 — cimientos de arquitectura

- crear `ui/features`, estados inmutables y comandos;
- registrar servicios/repositorios/ViewModels por constructor;
- implementar DB local, archivos cifrados, hash, ledger y outbox;
- definir errores tipados y logging con redacción de datos sensibles;
- agregar unit tests base.

Salida: una evidencia fixture se registra, recupera y verifica offline.

### Fase 2 — autenticación y requisas

- implementar AuthRepository/API/tokens/guards;
- listado con cursor, filtros y cache;
- crear/editar detalle;
- detalle remoto implementado y documentado en `docs/modules/requisitions_detail.md`, incluyendo lectura de evidencias/sesiones, creación de sesión y finalización; la recuperación FCE para uso offline y la galería interactiva ya tienen flujo conectado; continúa pendiente la cadena de custodia;
- estados y finalización inicial (la lectura, el sellado, la subida y la recuperación offline del detalle consumen la API; queda pendiente la validación probatoria completa);
- reemplazar mocks del home.

Salida: flujo login -> lista -> crear -> detalle, online/offline, probado.

### Fase 3 — sesión de adquisición

Estado al 4 de septiembre de 2026: vertical arquitectónica inicial implementada. Conexión y preparación scrcpy están detrás de `AcquisitionRepository`/servicio, ligadas a IDs de requisa/sesión y sin consola técnica en la View. Continúan pendientes el ledger, recuperación de proceso y pruebas repetidas de cleanup.

- contrato de capacidades y estado;
- refactor de `AdbClient`/plugin detrás de repositorio;
- clasificar dispositivos USB por interfaces y aceptar como objetivo de Mirror
  solamente la interfaz ADB exacta `255/66/1`;
- diagnosticar por separado no enumerado, sin ADB, permiso, claim, handshake y
  reenumeración;
- homologar un Android objetivo a través del ORICO usado como OTG de un solo
  puerto como gate previo a la multisesión obligatoria 1/2/3;
- conexión obligatoriamente ligada a requisa/sesión;
- cleanup de lifecycle, cancelación y diagnósticos;
- ocultar consola shell fuera de debug.

Salida: conectar/desconectar repetidamente sin fugas y con ledger.

### Fase 4 — evidencia de pantalla Android

Estado actualizado al 19 de noviembre de 2026: screenshot binario, control táctil validado, muxer MP4, SHA-256 local, contador de grabación, feedback flotante y galería en vivo implementados. El recorder conserva SPS/PPS, solicita a scrcpy un keyframe cada segundo, espera el siguiente posterior al toque, confirma entonces el estado `recording`, normaliza PTS y valida el archivo antes de registrarlo. Ya no precarga un GOP anterior, por lo que duración, imagen y contador comparten el mismo inicio. Las miniaturas de video se generan como JPEG derivados y cacheados para el panel de mirror y el detalle de requisa; la extracción local prueba varios frames, seek escalado y un extractor Android alternativo. El panel lista todas las evidencias, se inicializa al abrirse por primera vez y después se conserva fuera de pantalla. Sus celdas se identifican por `evidenceId`; insertar una captura/grabación reubica las existentes sin desmontarlas y solo prepara la nueva. Cuadrícula/lista comparten builder y subárbol de preview, mientras el difuminado sigue siendo una capa visual. El detalle resume seis elementos por categoría antes de **Ver todo**. Continúan pendientes la revalidación física del MP4 corregido y de los codecs OEM, cuotas/espacio, segmentación y manifiesto.

- screenshot binario;
- recording/muxer;
- barra foto/grabar, estados y errores;
- thumbnails y galería en vivo;
- manejo de desconexión/espacio insuficiente.

Salida: archivos reproducibles con hash y manifiesto, vinculados a requisa.

### Fase 4A — Mirror Android multisesión mediante ORICO

Objetivo obligatorio: mantener N Android objetivo con sesiones ADB/scrcpy
concurrentes e independientes. El ORICO valida primero 1/2/3 y un hub alimentado
de seis puertos valida después 4/5/6 sin cambiar la arquitectura. La secuencia,
arquitectura y matriz completas están en
[ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md](ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md).

- MM0: distinguir host inactivo, MTP sin ADB y ADB listo; diagnóstico y permiso
  por dispositivo implementados;
- MM1: un mirror por ORICO funciona en pruebas del propietario; falta repetir
  sistemáticamente por cada USB-A;
- MM2: registro de sesiones por `sourceSessionId` y `deviceId` implementado,
  preservando la API singular;
- MM3: selección múltiple y dos mirrors implementados y funcionales en pruebas
  del propietario; faltan soak y matriz de detach/reconnect;
- MM4: mantener tres mirrors con admisión de recursos y calidad adaptativa;
- MM5: retirar límites fijos y homologar progresivamente 4/5/6 en un hub de seis
  USB-A;
- MM6: rutas plurales y workspace responsive 1..N;
- MM7: soak tests, PD, permutación de puertos, capturas, grabaciones y
  atribución probatoria por fuente.
- MM8: generalizar la colección a `LiveVideoSource`, incorporar UVC por
  capacidades y homologar 1 UVC, 1 ADB + 1 UVC y 2 ADB + 1 UVC sin crear otro
  selector o workspace.

Rutas previstas:

```text
/requisitions/:requisitionId/acquisitions/:sessionId/mirrors/connect
/requisitions/:requisitionId/acquisitions/:sessionId/mirrors/live
```

Las rutas singulares actuales continúan como compatibilidad y fallback. Mirror
múltiple no reescribe ADB/scrcpy: crea una instancia aislada del pipeline
existente por objetivo.

Estado al 17 de noviembre de 2026: el mirror individual limita preventivamente
el borde de video a 1600 px en objetivos mayores; 2/3/N sesiones parten de
1280/1024/800 px. Todos conservan una escala descendente. Un rechazo del socket
porque el proceso scrcpy terminó durante un reinicio se considera recuperable,
el cleanup espera la liberación del encoder OEM y continúa con el siguiente
tamaño. El transporte aplica contrapresión solo al stream H.264 para evitar
latencia acumulada sin afectar control, shell ni transferencia.

Actualización UI al 19 de noviembre de 2026: mirror individual y múltiple
reutilizan el mismo panel de evidencias. Su estado visual y miniaturas permanecen
montados entre aperturas repetidas dentro de la composición responsive actual;
las inserciones y el cambio cuadrícula/lista conservan los previews existentes
por ID. El operador puede activar un difuminado moderado de previews. En
multimirror el contexto sigue indicando la fuente enfocada, sin cambiar la
atribución de capturas o grabaciones.

Salida: N previews activos hasta `maxConcurrentSources`, con control dirigido
solo a fuentes capaces, acciones por objetivo y desconexión individual sin
afectar las otras sesiones; primera homologación de tres y ampliación de seis.

### Fase 5 — transferencia Android

Estado al 8 de septiembre de 2026: browser responsive, selector entre contenido común y almacenamiento compartido completo, preview temporal y responsive de imágenes, videos, audios, PDF, DOCX y texto estructurado, conexión dirigida, `LIST`/`STAT`/`RECV`, lote secuencial, progreso, cancelación y registro local en el detalle implementados. La implementación se limita a `/sdcard` y a lo accesible para `shell`, no altera el dispositivo objetivo y conserva como deuda la validación física, los formatos ofimáticos legados y las garantías probatorias.

- sync pull/list/stat;
- browser de archivos accesibles;
- alternativa companion con selectores del sistema;
- progreso, cancelación, lote y deduplicación por hash.

Salida: imágenes/videos elegidos aparecen como evidencias verificadas.

### Fase 6 — sincronización y sellado

- uploads por chunks, receipts y retry;
- reconciliación y conflictos;
- manifiesto final y hash raíz;
- bloqueo post-finalización y adendas.

Salida: prueba offline -> reconnect -> sync -> seal sin pérdida ni duplicado.

### Fase 7 — PoC iOS USB y UVC

- PoC HDMI/UVC con la capturadora UGREEN en inspector Android y en iPad Air 4
  con iPadOS 27, para objetivos Lightning, iPhone USB-C y Android con salida
  HDMI;
- conservar sin cambios funcionales el transporte ADB/scrcpy, decoder,
  recorder, control y ADB Sync ya operativos mientras se demuestra UVC;
- reutilizar el ORICO homologado en la Fase 4A para probar una capturadora sola,
  luego 1 ADB + 1 UVC y finalmente 2 ADB + 1 UVC;
- conservar Mirror y Capturadora como acciones distintas del launcher, pero
  integrarlas en el selector y workspace single/multi existentes mediante
  transporte y capabilities; no crear Views `capture-card` duplicadas;
- PoC `libimobiledevice` en inspector Android para pairing y AFC de solo lectura;
- gate legal de LGPL/GPL y SBOM del stack nativo;
- pruebas en iPhone Lightning/USB-C y versiones soportadas;
- documentar capacidades reales y cambios inevitables por pairing;
- evaluar MobileBackup2 solamente después de aprobar AFC.

Salida: ADR iOS con demostración repetible, matriz y límites visibles; no continuar si los gates de [IOS_USB_LIBIMOBILEDEVICE_PLAN.md](IOS_USB_LIBIMOBILEDEVICE_PLAN.md) no se cumplen.

### Fase 8 — UI adaptive y accesibilidad

- aplicar la infraestructura de `lib/ui/core/adaptive/` y la skill responsive;
- trabajar una vertical pequeña por sesión;
- construir list/detail, modal y adquisición a partir de mockups;
- teclado, mouse/trackpad, foco y shortcuts en tablet;
- text scaling, contraste, targets y golden tests.

La limpieza transversal de ScreenUtil, `OrientationBuilder`, helpers responsive, tokens legacy y rutas de `presentation` se completó el 31 de agosto de 2026. No reintroducir infraestructura paralela.

Salida: cero overflow y UX usable en la matriz de viewports.

### Fase 9 — validación, seguridad y piloto

- tests unit/widget/integration/native/protocol;
- soak tests de grabación y transferencias grandes;
- threat model, pentest, revisión de claves y privacidad;
- SBOM, firmas, CI de release y rollback;
- manual operativo y reporte exportable;
- validación forense con artefactos conocidos.

Salida: aprobación de piloto limitada a la matriz validada.

## Estrategia de pruebas

### Unitarias

Todos los servicios, repositorios, use cases y ViewModels. Casos obligatorios: idempotencia, conflictos, hash incorrecto, poco espacio, cancelación, reconexión y sellado.

### Widget/golden

Estados loading/empty/error/offline, text scale, temas y viewports de la guía responsive.

### Android nativo

- ADB packets con golden bytes y CRC;
- RSA/auth con vectores conocidos;
- fragmentación/coalescencia de streams;
- backpressure;
- paquetes de control por versión scrcpy;
- MP4 válido después de desconexión inesperada;
- pull con archivos 0 B, grandes, unicode y nombres hostiles.

### Integración física

Ejecutar cada capacidad en la matriz de [HARDWARE_REQUIREMENTS.md](HARDWARE_REQUIREMENTS.md). Guardar build, cable/hub, modelos, OS, resultado, logs y hash del fixture.

## Definition of Done por feature

- View sin IO ni lógica de negocio.
- ViewModel con estado inmutable y comandos protegidos de doble ejecución.
- servicios/repositorios inyectados, sin singletons ocultos de sesión.
- errores tipados y observables.
- cleanup/cancelación documentados.
- unit tests y al menos una prueba de integración relevante.
- comportamiento offline definido.
- accesibilidad y viewports verificados.
- datos sensibles no aparecen en logs.
- evidencia y ledger conservan hash antes/después de sync.
- documentación/ADR actualizados.

## Orden inmediato recomendado

1. Revalidar en hardware los ajustes leves de mirror individual/múltiple,
   grabación, previews y detach; completar ORICO ADB 1/2/3.
2. Crear el contrato `LiveVideoSource`/capabilities sin modificar el protocolo
   ADB/scrcpy y adaptar la sesión multi actual.
3. Implementar la PoC UGREEN directa en Android a 1080p30, con preview, captura,
   grabación y cleanup propios.
4. Registrar UVC en el selector/workspace existente y validar una sola fuente.
5. Homologar por ORICO 1 ADB + 1 UVC y 2 ADB + 1 UVC, incluyendo pérdida de
   HDMI, detach, reload y evidencia atribuida por fuente.
6. Implementar el adapter iPad Air 4/AVFoundation sobre el mismo contrato Dart.
7. Mantener AFC/libimobiledevice como PoC separada de archivos y continuar
   ledger, hardening, CI y validación probatoria antes del piloto.

## Referencias

- [Flutter architecture guide](https://docs.flutter.dev/app-architecture/guide)
- [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Android USB host](https://developer.android.com/develop/connectivity/usb/host)
- [Android shared media](https://developer.android.com/training/data-storage/shared/media)
- [Android Storage Access Framework](https://developer.android.com/training/data-storage/shared/documents-files)
- [scrcpy oficial](https://github.com/Genymobile/scrcpy/)
- [Apple ReplayKit](https://developer.apple.com/documentation/replaykit)
- [Apple Multipeer Connectivity](https://developer.apple.com/documentation/MultipeerConnectivity)
- [Apple PhotoKit](https://developer.apple.com/documentation/PhotoKit)
- [libimobiledevice oficial](https://github.com/libimobiledevice/libimobiledevice)
- [usbmuxd oficial](https://github.com/libimobiledevice/usbmuxd)
- [NIST SP 800-101 Rev. 1](https://csrc.nist.gov/pubs/sp/800/101/r1/final)
