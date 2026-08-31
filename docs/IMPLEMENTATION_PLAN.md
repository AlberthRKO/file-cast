# Plan de implementación de File Cast

Este documento convierte el objetivo del producto y los tres mockups en un plan técnico. Debe leerse junto con [PROJECT_STATUS_AND_FEASIBILITY.md](PROJECT_STATUS_AND_FEASIBILITY.md), [HARDWARE_REQUIREMENTS.md](HARDWARE_REQUIREMENTS.md), [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md), [RESPONSIVE_GUIDE.md](RESPONSIVE_GUIDE.md) y [ROUTING_GUIDE.md](ROUTING_GUIDE.md). El avance concreto se registra en [MIGRATION_TRACKER.md](MIGRATION_TRACKER.md). Para migrar una vista usar [SINGLE_VIEW_REFACTOR_PROMPT.md](SINGLE_VIEW_REFACTOR_PROMPT.md); para fases amplias y limpieza final usar [RESTRUCTURING_PROMPT.md](RESTRUCTURING_PROMPT.md).

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
8. almacene cada evidencia localmente con integridad verificable;
9. sincronice al servicio cuando haya conectividad;
10. finalice y selle la requisa sin perder el historial de custodia.

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
canReceiveUserSelectedFiles
canCaptureAudio
requiresCompanionApp
requiresDesktopBridge
```

La UI habilitará acciones según estas capacidades. Así iOS no necesita simular funciones que el sistema no ofrece.

### 3. Dos rutas iOS

- **Ruta A — app compañera:** el usuario instala/abre File Cast Companion en el iPhone/iPad, elige archivos con PhotoKit/Document Picker y, si corresponde, inicia una transmisión ReplayKit desde el selector del sistema. Los datos viajan cifrados por red local a la sesión de requisa.
- **Ruta B — estación macOS:** el dispositivo se conecta por cable a una Mac autorizada. Un servicio local de adquisición captura pantalla/importa datos autorizados y entrega los artefactos a la app/API de la requisa.

La Ruta A es más móvil y explícita; la Ruta B se aproxima al requisito de cable y cubre mejor modelos iOS sin instalar una app, pero agrega hardware y un servicio de escritorio.

### 4. Evidencia inmutable; anotaciones separadas

Nunca editar el archivo original. Recortes, compresiones, thumbnails, OCR o anotaciones crean derivados con su propio hash y referencia al original.

### 5. Offline-first

Crear y consultar requisas asignadas, capturar evidencia y mantener el ledger debe funcionar sin internet. La sincronización será un proceso idempotente y reanudable.

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

`presentation/` se migrará progresivamente a `ui/`. No se recomienda un rename masivo antes de tener pruebas; cada feature nueva entra con la estructura objetivo y reemplaza la pantalla anterior al completar su vertical.

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

El detalle y las reglas de migración están en [ROUTING_GUIDE.md](ROUTING_GUIDE.md).

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
- `IosCompanionPlatformService` o `MacBridgeService`
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

Implementar ADB sync completo:

- `STAT`/`LIST` para metadatos;
- `RECV`/`DATA`/`DONE` para pull;
- cancelación, progreso, timeout y hash;
- nombres seguros y protección contra path traversal;
- límites de tamaño/cuota;
- selección múltiple y reanudación si el protocolo lo permite.

Dos UX posibles:

- **Galería accesible por ADB:** mostrar DCIM/Pictures/Movies/Download que el usuario `shell` pueda leer. No implica acceso a datos privados de apps.
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

### Ruta A — Companion

1. Crear target iOS y Broadcast Upload Extension.
2. Mostrar el selector de broadcast del sistema; el usuario inicia/detiene la captura.
3. Emparejar inspector y objetivo mediante QR/código efímero.
4. Autenticar la sesión con claves efímeras y cifrado en tránsito.
5. Transmitir segmentos con números de secuencia y hash.
6. Usar PhotoKit/Document Picker para archivos seleccionados.
7. Registrar interrupciones, background y permisos denegados como eventos de sesión.

Limitaciones visibles en UI: requiere interacción del usuario, puede haber contenido protegido/no capturable, no permite inyectar toques generales y el browsing/anuncio local se interrumpe en background.

### Ruta B — Mac Bridge

1. Servicio macOS firmado, registrado como estación de adquisición.
2. Detectar dispositivo confiado y desbloqueado.
3. Capturar el feed que macOS expone para el dispositivo conectado.
4. Importar artefactos autorizados a un staging cifrado.
5. Calcular hash y emitir un manifiesto firmado por la estación.
6. Enviar a la API o a la app inspector mediante canal autenticado.
7. Asociar todo a `requisitionId` y `acquisitionSessionId`.

La primera PoC iOS debe probar solo: detectar/trust, obtener video, crear MP4, importar un archivo seleccionado, hash y registro. Si falla esa prueba en la matriz requerida, detener la promesa de cable directo y usar solo Companion.

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

## Fases de entrega

### Fase 0 — alcance, laboratorio y toolchain

- fijar Flutter/Dart en FVM/mise y CI;
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
- estados y finalización inicial;
- reemplazar mocks del home.

Salida: flujo login -> lista -> crear -> detalle, online/offline, probado.

### Fase 3 — sesión de adquisición

- contrato de capacidades y estado;
- refactor de `AdbClient`/plugin detrás de repositorio;
- conexión obligatoriamente ligada a requisa/sesión;
- cleanup de lifecycle, cancelación y diagnósticos;
- ocultar consola shell fuera de debug.

Salida: conectar/desconectar repetidamente sin fugas y con ledger.

### Fase 4 — evidencia de pantalla Android

- screenshot binario;
- recording/muxer;
- barra foto/grabar, estados y errores;
- thumbnails y galería en vivo;
- manejo de desconexión/espacio insuficiente.

Salida: archivos reproducibles con hash y manifiesto, vinculados a requisa.

### Fase 5 — transferencia Android

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

### Fase 7 — PoC iOS y decisión de ruta

- PoC Companion;
- PoC Mac Bridge;
- pruebas en iPhone Lightning/USB-C y versiones soportadas;
- documentar capacidades reales;
- seleccionar una o ambas rutas.

Salida: ADR iOS con demostración repetible; no continuar si el criterio no se cumple.

### Fase 8 — UI adaptive y accesibilidad

- aplicar [RESPONSIVE_GUIDE.md](RESPONSIVE_GUIDE.md);
- migrar una vista por sesión según [MIGRATION_TRACKER.md](MIGRATION_TRACKER.md);
- construir list/detail, modal y adquisición a partir de mockups;
- teclado, mouse/trackpad, foco y shortcuts en tablet;
- text scaling, contraste, targets y golden tests.

La eliminación transversal de ScreenUtil, `OrientationBuilder`, helpers responsive, temas/tokens legacy y rutas de `presentation` ocurre solo después de completar el gate del tracker. No forma parte automática de la migración de una vista.

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

1. Migrar Started y Login con los prompts directos, manteniendo Home/listado como referencia de la arquitectura nueva.
2. Migrar Offline y Settings; decidir el shell solo con destinos reales.
3. Implementar crear/detalle de requisa antes de conectar adquisición a IDs reales.
4. Congelar el prototipo ADB como referencia y migrar Connect/Mirror sin reescribir el protocolo.
5. Implementar dominio/almacenamiento/ledger antes de los botones probatorios.
6. Implementar screenshot, recording y pull Android.
7. Ejecutar PoC iOS y decidir ruta.
8. Cumplir el gate y ejecutar la limpieza global final del responsive/tema/rutas legacy.
9. Corregir el SDK reproducible, aplicar hardening, validación y piloto según autorización del propietario.

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
- [NIST SP 800-101 Rev. 1](https://csrc.nist.gov/pubs/sp/800/101/r1/final)
