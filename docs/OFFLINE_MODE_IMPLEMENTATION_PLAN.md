# Plan integral de modo offline para File Cast

Fecha de elaboración: 20 de noviembre de 2026
Alcance revisado: Flutter/Dart, persistencia SQLCipher, cifrado FCE, autenticación,
requisas, detalle, evidencias, WorkManager, navegación `go_router`, mirror Android
individual/múltiple y bridge nativo ADB/scrcpy.

Este documento debe leerse junto con:

- [PROJECT_STATUS_AND_FEASIBILITY.md](PROJECT_STATUS_AND_FEASIBILITY.md);
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md);
- [CLIENT_SIDE_ENCRYPTION.md](CLIENT_SIDE_ENCRYPTION.md);
- [HARDWARE_REQUIREMENTS.md](HARDWARE_REQUIREMENTS.md);
- [ADB_HANDSHAKE.md](ADB_HANDSHAKE.md);
- [LOCAL_SQLITE_DATABASE_DIAGRAM.md](LOCAL_SQLITE_DATABASE_DIAGRAM.md);
- [ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md](ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md).

> Límite de este plan: “sin fallos” no puede significar ausencia absoluta de
> fallas de hardware, almacenamiento, energía, red o backend. El objetivo es que
> ninguna falla prevista pierda, duplique, reasigne o exponga evidencia, y que
> toda operación quede en un estado recuperable y visible. Los gates de
> aceptación de este documento son los que permiten demostrarlo.

## Estado de implementación — 23 de noviembre de 2026

Primera vertical operativa implementada en el cliente Flutter:

- fuente global de conectividad que distingue `online`, `offline`, `limited` y
  `checking`, validando el backend institucional;
- badge flotante, compacto y responsive en el `builder` raíz, visible sólo
  cuando la app trabaja sin backend (`offline` o `limited`);
- migración SQLCipher v9 con cache de listado, snapshots de detalle y sesiones
  de adquisición locales, todo aislado por cuenta autenticada;
- aislamiento por cuenta agregado también a las evidencias locales y a la
  selección de trabajos de la outbox;
- repositorio de requisas `offline-first`: red con escritura de cache y fallback
  persistente con búsqueda, filtro y paginación local; el catálogo completo sin
  filtros se calienta en segundo plano, se reemplaza atómicamente por cuenta y
  retira snapshots obsoletos sin borrar evidencia local pendiente;
- detalle persistente reconstruible después de cerrar el proceso, combinado con
  los FCE locales ya existentes;
- creación de sesión local sin HTTP para habilitar mirror individual/múltiple,
  transferencia, captura, grabación e importación sin conexión;
- resolución automática `localSessionId -> remoteSessionId` antes de cargar la
  primera evidencia, usando una clave de idempotencia estable;
- conservación del flujo existente para preparar y verificar evidencias remotas
  destinadas a visualización offline;
- lectura local inmediata en autenticación, lista y detalle cuando el backend no
  está disponible, sin esperar el timeout HTTP;
- bloqueo explícito de mutaciones remotas en offline, manteniendo habilitada la
  adquisición local y dejando sus evidencias en outbox;
- reconciliación de sesiones locales cerradas y preflight de almacenamiento para
  captura y grabación individual/múltiple.

Esta vertical todavía no cierra la Definition of Done integral. Permanecen como
fases posteriores: política temporal/revocación de autenticación offline,
cursor/tombstones del backend, ledger append-only, upload reanudable por chunks,
receipts de integridad, cuotas/retención y la matriz de validación automática y
física. No se ejecutaron compilaciones, tests, `flutter analyze`, `flutter run`,
generadores ni builds nativos durante esta implementación, conforme a las reglas
del repositorio.

## 1. Objetivo de producto

Después de haber iniciado sesión y sincronizado al menos una vez en un dispositivo
autorizado, el operador debe poder, sin internet y después de cerrar o reiniciar la
aplicación:

1. abrir File Cast con una sesión offline válida;
2. ver las requisas que tenía asignadas en la última sincronización;
3. filtrar y abrir el detalle persistido de una requisa;
4. consultar sus metadatos, sesiones y evidencias disponibles localmente;
5. previsualizar los FCE que ya estén preparados para uso offline;
6. iniciar una sesión de adquisición local ligada a requisa y operador;
7. ejecutar mirror Android individual o múltiple por USB/ADB/scrcpy;
8. capturar imágenes, grabar videos, transferir archivos o importarlos;
9. cifrar y registrar cada evidencia localmente aunque nunca haya existido red
   durante la adquisición;
10. conservar todo después de cierre, reinicio, desconexión USB o fallo de subida;
11. sincronizar sesiones, evidencias y eventos al recuperar una conexión válida;
12. confirmar claramente qué quedó local, pendiente, subiendo, verificado o con
    intervención requerida.

La aplicación debe mostrar en todas las pantallas un badge flotante únicamente
cuando trabaja sin backend: **Sin conexión** o **Sin conexión al servidor**. En
línea y durante la comprobación inicial no se ocupa espacio con un indicador. El
modo offline no debe redirigir a una pantalla que impida usar la aplicación.

## 2. Alcance funcional y límites

### 2.1 Incluido en la primera entrega operativa

- cold start offline con una sesión previamente autorizada;
- listado y detalle persistidos de requisas asignadas;
- inventario de evidencias y preview local de las copias FCE disponibles;
- mirror individual y múltiple sin dependencia del backend durante la sesión;
- captura, grabación, transferencia ADB e importación local;
- IDs locales estables para sesiones y evidencias;
- outbox con dependencias, idempotencia, backoff y reanudación;
- sincronización automática y manual cuando vuelve el backend;
- badge global y centro de estado de conexión/sincronización;
- aislamiento por cuenta, cifrado local, cuotas y recuperación ante cierre.

### 2.2 Acciones con comportamiento restringido offline

| Acción | Comportamiento offline recomendado |
|---|---|
| Primer login en un dispositivo | Requiere internet. No almacenar contraseña para simular login. |
| Consultar requisas/detalle | Leer inmediatamente SQLCipher; refrescar en segundo plano solo si el backend está disponible. |
| Crear sesión de adquisición | Crear una sesión local y encolar su creación remota. |
| Mirror/captura/grabación/transferencia/importación | Disponible sin red si la requisa cacheada permite adquisición. |
| Renombrar evidencia local no subida | Aplicar localmente y sincronizar como parte de la evidencia. |
| Cambiar sujetos de una evidencia local | Aplicar localmente; incluir el snapshot/IDs en la subida. |
| Renombrar o cambiar sujetos de evidencia ya remota | Encolar operación versionada o deshabilitar hasta la Fase 5; nunca aparentar confirmación remota. |
| Agregar participantes, cambiar roles o vincular CUD | Requiere conexión y autorización actual, porque afecta acceso a datos y claves. |
| Sellar requisa | Puede encolarse como intención, pero la UI no muestra **Sellada** hasta que el servidor verifique todas las evidencias y confirme el manifiesto. |
| Cerrar sesión | Debe pedir una decisión explícita sobre datos pendientes; nunca borrar evidencia no sincronizada. |

### 2.3 Fuera de alcance

- prometer acceso offline en un dispositivo que nunca autenticó ni recibió datos;
- controlar iPhone mediante ADB/scrcpy;
- eliminar automáticamente evidencia local no confirmada por el servidor;
- resolver silenciosamente conflictos probatorios;
- hacer que `connectivity_plus` sea prueba suficiente de acceso al backend;
- sincronizar durante un `force-stop` que el sistema operativo prohíba ejecutar.

## 3. Diagnóstico del estado actual

### 3.1 Capacidades que ya sirven como base

- `AuthSessionService` conserva tokens y un usuario cacheado; ante un fallo de red
  durante restauración puede devolver ese perfil local.
- `LocalEvidenceDatabaseService` usa SQLCipher y guarda `evidencias_locales`,
  `outbox_evidencias` y `sync_locks`.
- `EvidenceCryptoService` crea FCE AES-256-GCM, hashes de plano/ciphertext y una
  DEK envuelta por la bóveda local.
- `EvidenceSyncService` conserva evidencia ante error, reclama filas de forma
  atómica y escucha cambios de conectividad.
- WorkManager agenda carga de outbox y preparación de evidencias remotas para
  uso offline.
- las evidencias remotas `AVAILABLE` pueden descargarse, verificarse y quedar
  persistidas como FCE local sin reinsertarse en la outbox;
- captura, grabación y transferencia nativa reciben `requisitionId`/`sessionId`,
  escriben en almacenamiento privado y entregan metadatos a Flutter;
- mirror individual y múltiple ya separan sesiones/fuentes nativas y no necesitan
  internet una vez iniciados;
- rutas de adquisición ya llevan requisa y sesión en path parameters.

### 3.2 Estado actual y brechas remanentes

| Área | Estado observado | Brecha offline |
|---|---|---|
| Sesión de usuario | El perfil cacheado se restaura inmediatamente sin red | Falta aprobar vigencia máxima offline, revocación y estado explícito `offlineAuthenticated`. |
| Conectividad | Fuente global inyectada valida el backend y reintenta periódicamente | Falta telemetría operativa y un endpoint de health dedicado si el backend lo publica. |
| Badge global | Badge flotante visible sólo en `offline`/`limited` | Falta validación visual física sobre todas las pantallas y escalas de texto. |
| Listado | SQLCipher sirve búsqueda, filtro y paginación local; el catálogo se completa en segundo plano | El backend todavía no ofrece cursor/tombstones incrementales; se usa reemplazo atómico tras catálogo completo. |
| Detalle | Snapshot persistido y precarga secuencial de detalles faltantes | Los snapshots necesitan versión/cursor de servidor para revocaciones incrementales. |
| Sesión de adquisición | Se crea UUID local sin HTTP y luego se mapea a sesión remota idempotente | Falta una outbox genérica para cierre/cancelación iniciados offline. |
| Catálogo local | Persiste requisas, detalles, sesiones y mapping local/remoto | Faltan fuentes normalizadas, ledger y operaciones generales. |
| Sincronización | Sesión remota antes de evidencia, outbox y reintento automático | La evidencia aún sube como multipart completo; faltan chunks, receipts y conflictos versionados. |
| Multi mirror | Captura/grabación local usa requisa y sesión, con preflight de espacio | La identidad probatoria completa de cada fuente debe persistirse fuera del nombre del archivo. |
| Cuenta y permisos | Cache, sesiones y evidencias están particionados por `account_id` | Falta snapshot versionado de permisos y política de revocación. |
| Custodia | Hash y metadatos parciales | Falta ledger append-only y recuperación transaccional completa ante cierres. |
| Espacio | Transferencia, captura y grabación hacen preflight con reserva mínima | Falta cuota global, límite durante grabaciones largas, retención y manejo continuo de presión de disco. |

Conclusión: File Cast ya cubre el vertical cliente de **cuenta, catálogo,
detalle, sesión local, evidencia cifrada y outbox**. La Definition of Done
probatoria completa aún requiere contratos de backend y política institucional
para cursor/revocación, chunks, receipts, ledger, cuotas y retención.

## 4. Decisiones de arquitectura

### 4.1 Offline-first, no “remote con fallback”

Los repositorios pasan a ser la única fuente de verdad y leen primero la base
local. Los servicios remotos solo refrescan y reconcilian esa fuente local.

```text
View
  -> ViewModel
      -> UseCase cuando coordina varias reglas
          -> Repository (fuente de verdad)
              ├─ Local service / SQLCipher / FCE
              ├─ Remote API service
              └─ Native acquisition service
```

Regla de lectura:

```text
abrir pantalla
  -> emitir snapshot local inmediatamente
  -> si el backend está disponible, solicitar cambios
  -> validar versión/autorización
  -> aplicar respuesta en una transacción
  -> emitir el nuevo snapshot
```

Regla de escritura offline:

```text
intención del operador
  -> validar permiso cacheado, estado y espacio
  -> escribir cambio local + operación outbox en una transacción
  -> actualizar UI como "pendiente", nunca como "confirmado por servidor"
  -> sincronizar cuando exista backend y sesión válidos
```

### 4.2 Mantener la base existente y migrarla sin perder evidencia

No crear otra base paralela ni renombrar de inmediato
`file_cast_evidence_v1.db`. Se debe subir su versión mediante migraciones
idempotentes y convertir `LocalEvidenceDatabaseService` gradualmente en una
fachada sobre un `FileCastLocalDatabaseService` compartido.

La migración nunca debe borrar filas FCE existentes. Las filas históricas sin
cuenta se vinculan únicamente si hay un solo usuario cacheado inequívoco; en
cualquier otro caso quedan en cuarentena local para reconciliación y no se
mostrarán a otra cuenta.

### 4.3 IDs locales permanentes y mapping remoto

- `localRequisitionId`, `localSessionId`, `evidenceId`, `custodyEventId` y
  `clientOperationId` serán UUID generados antes de cualquier llamada HTTP.
- El backend debería aceptar esos UUID como ID cliente. Si no puede hacerlo, se
  persiste `remoteId` separado y una tabla de mappings.
- Las rutas y carpetas nativas usan siempre el ID local estable; al sincronizar
  no se renombran carpetas ni archivos.
- Cada request reintentable reutiliza el mismo `Idempotency-Key`; no genera una
  clave aleatoria por intento como ocurre hoy al crear sesiones.

### 4.4 No modificar el protocolo ADB/scrcpy

El modo offline no requiere reescribir handshake, transporte, decoder, control o
recorder. Solo debe recibir IDs locales válidos y devolver metadatos completos de
fuente. Los cambios nativos se limitan a persistencia/atribución y recuperación,
manteniendo el protocolo ya validado.

## 5. Modelo local objetivo

Los nuevos modelos de dominio, DTO y snapshots de estado deben ser inmutables y
usar Freezed. Los DTO JSON pertenecen a `data`; el dominio no depende de Flutter,
SQLite, plugins ni HTTP.

### 5.1 Tablas

#### `offline_accounts`

```text
account_id PK, actor_id, device_id, profile_json,
last_online_auth_at, offline_access_expires_at,
permission_snapshot_hash, status, created_at, updated_at
```

#### `requisition_snapshots`

```text
account_id + requisition_id PK,
server_version, status, summary_json, detail_json,
permission_snapshot, offline_readiness,
last_synced_at, deleted_at?, updated_at
```

`detail_json` es un DTO versionado de frontera, no un modelo de dominio incrustado
en UI. Campos usados para búsqueda/filtro deben tener columnas e índices propios.

#### `acquisition_sessions`

```text
local_id PK, remote_id?, account_id, requisition_id,
operator_id, source_platform, transport, capabilities_json,
status, opened_at_utc, opened_monotonic_offset,
closed_at_utc?, sync_state, client_operation_id UNIQUE,
last_error_code?, created_at, updated_at
```

Estados mínimos:

```text
LOCAL_OPEN -> PENDING_CREATE -> REMOTE_OPEN -> PENDING_COMPLETE -> COMPLETED
                          \-> ERROR_RETRYABLE / ERROR_ACTION_REQUIRED
```

#### `acquisition_sources`

```text
source_local_id PK, local_session_id, source_session_id,
transport, usb_device_fingerprint, model, os_version,
capabilities_json, connected_at, disconnected_at?, metadata_json
```

La huella visible no debe exponer seriales completos en logs o UI.

#### `evidencias_locales` ampliada

Agregar sin perder las columnas actuales:

```text
account_id, local_session_id, remote_session_id?, source_local_id?,
captured_at_utc, captured_monotonic_offset,
sync_state, upload_id?, uploaded_parts_json?, server_receipt_json?,
custody_head_hash?, retry_after?, last_error_code?
```

Máquina de estados recomendada:

```text
CAPTURING -> VERIFYING_LOCAL -> LOCAL_ONLY -> WAITING_SESSION
 -> PREPARING_KEYS -> READY_TO_UPLOAD -> UPLOADING -> VERIFYING_REMOTE -> SYNCED
                                      \-> PAUSED
                                      \-> ERROR_RETRYABLE
                                      \-> ERROR_ACTION_REQUIRED
```

#### `sync_operations`

Reemplaza gradualmente una outbox exclusiva de evidencias por operaciones
generales:

```text
operation_id PK, account_id, aggregate_type, aggregate_local_id,
operation_type, payload_json, depends_on_operation_id?,
idempotency_key UNIQUE, base_server_version?, state,
attempt_count, next_attempt_at?, last_error_code?, last_error_message?,
created_at, updated_at
```

Operaciones iniciales:

```text
CREATE_ACQUISITION_SESSION
UPLOAD_EVIDENCE
COMPLETE_ACQUISITION_SESSION
RENAME_EVIDENCE
SET_EVIDENCE_SUBJECTS
REQUEST_FINALIZE_REQUISITION
```

#### `sync_cursors`

```text
account_id + stream PK, cursor, last_server_time, last_success_at
```

#### `custody_events`

```text
id PK, account_id, requisition_id, local_session_id?, evidence_id?,
sequence, event_type, actor_id, occurred_at_utc, monotonic_offset,
device_id, payload_hash, previous_event_hash, event_hash,
remote_receipt?, sync_state
```

Los eventos son append-only. Corregir metadata crea un evento/adenda; no modifica
el evento histórico.

### 5.2 Índices y restricciones

- todas las consultas se filtran por `account_id`;
- unique de `client_operation_id` e `idempotency_key`;
- foreign keys requisa -> sesión -> fuente/evidencia;
- índices de `sync_state`, `next_attempt_at`, `requisition_id`, `created_at`;
- `CHECK` para estados enumerados y tamaños no negativos;
- activar foreign keys y verificar integridad al abrir la base;
- no guardar bytes planos en SQLite.

## 6. Servicios, repositorios y casos de uso

### 6.1 Conectividad global

Crear un `ConnectivityRepository` correctamente nombrado e inyectado. Debe
combinar:

1. estado del enlace reportado por `connectivity_plus`;
2. reachability HTTPS al dominio institucional, no a Google/8.8.8.8;
3. health del backend con timeout corto;
4. validez de sesión/refresh cuando una operación autenticada lo requiera;
5. estado del sincronizador y fecha de última confirmación.

Estados de dominio:

```text
checking
offline             # sin enlace o backend inalcanzable
limited             # enlace/captive portal/backend degradado/auth pendiente
online
syncing
```

La transición debe tener debounce para evitar parpadeos y no iniciar varios
sincronizadores cuando la red fluctúa.

### 6.2 Requisas y detalle

Sustituir `RemoteRequisitionRepository` por una implementación offline-first:

```text
OfflineFirstRequisitionRepository
  -> LocalRequisitionService
  -> RequisitionService (HTTP)
  -> SyncRepository
```

El listado observa SQLCipher. La paginación remota actual se materializa en
local y los filtros se ejecutan localmente cuando no hay red. Un refresh remoto
actualiza todas las columnas auxiliares y el snapshot en la misma transacción.

`RemoteRequisitionDetailRepository` debe dejar de depender de
`_cachedRemoteDetails` como única copia. `getDetail()` lee SQLCipher; el `Map` en
memoria puede quedar solo como optimización. La mezcla de evidencia local debe
ser determinista y transaccional.

### 6.3 Sesiones de adquisición

Crear `StartAcquisitionSessionUseCase`:

```text
validar cuenta/requisa/permiso cacheado/estado/espacio
  -> crear localSessionId y evento SESSION_OPENED
  -> persistir sesión local
  -> encolar CREATE_ACQUISITION_SESSION
  -> devolver localSessionId inmediatamente
```

`ensureAcquisitionSession()` no llama primero al backend. Mirror, transferencia e
importación reciben el ID local. Si existe conexión, la sincronización de la
sesión puede ocurrir enseguida, pero nunca bloquea la adquisición por una caída
de red.

### 6.4 Registro atómico de evidencia

Crear/reutilizar `RegisterEvidenceAtomicallyUseCase` para todos los orígenes:

```text
validar requisa/sesión/fuente/espacio
  -> producir archivo .part
  -> hash y validación de formato
  -> cifrar a FCE .part
  -> fsync archivo y directorio
  -> rename atómico
  -> transacción SQLCipher:
       Evidence + CustodyEvent + SyncOperation
  -> eliminar plano
  -> generar thumbnail derivado
  -> emitir cambio al repositorio
```

Si el proceso muere:

- un barrido al iniciar elimina temporales huérfanos vencidos;
- un FCE final sin fila se pone en cuarentena y se intenta recuperar desde su
  manifiesto lateral mínimo;
- una fila sin archivo se marca `ERROR_ACTION_REQUIRED` y nunca se presenta como
  sincronizable;
- una evidencia `SYNCED` conserva receipt/hash antes de ser elegible para
  retención o borrado.

### 6.5 Orquestación de sincronización

Crear `SyncRepository` y `SynchronizeOfflineWorkUseCase`. Un solo coordinador por
cuenta procesa el grafo de operaciones; la UI y WorkManager comparten claims y
leases en SQLCipher.

Orden al recuperar conexión:

1. validar/restaurar sesión del operador;
2. descargar cambios de acceso, versiones y tombstones;
3. bloquear/quarantinar agregados cuyo acceso fue revocado, sin borrarlos;
4. crear sesiones remotas pendientes con la misma idempotency key;
5. persistir mapping `localSessionId -> remoteSessionId`;
6. preparar envolturas de clave para destinatarios actualmente autorizados;
7. iniciar/reanudar uploads de evidencia;
8. verificar tamaño/hash en servidor y guardar receipt;
9. emitir eventos de custodia de carga/verificación;
10. completar sesiones locales cerradas;
11. procesar cambios de metadata y finalización pendientes;
12. volver a descargar cambios y avanzar el cursor solo después del commit local.

Los errores se clasifican:

| Clase | Ejemplos | Acción |
|---|---|---|
| Reintentable | timeout, 5xx, red inestable | backoff exponencial con jitter y `next_attempt_at`. |
| Autenticación | token expirado | pausar, intentar refresh una vez, solicitar login sin perder outbox. |
| Autorización | 403/requisa revocada | `ERROR_ACTION_REQUIRED`, cuarentena y flujo de supervisor. |
| Conflicto | versión/ETag distinto | detener esa operación, conservar ambos snapshots y pedir resolución explícita. |
| Integridad | hash/receipt no coincide | detener, conservar FCE local, no reintentar ciegamente. |
| Capacidad | 413/cuota backend | acción requerida; nunca borrar el original. |

## 7. Contrato necesario con backend

La app puede cachear y crear evidencia local sin cambios de backend, pero una
sincronización completa y segura requiere contrato server-side. Como mínimo:

```text
GET  /api/v1/sync/bootstrap
GET  /api/v1/sync/changes?cursor=...
POST /api/v1/sync/operations

POST /api/v1/requisitions/{id}/sessions
POST /api/v1/requisitions/{id}/sessions/{id}/complete

POST /api/v1/requisitions/{id}/evidence-uploads
PUT  /api/v1/evidence-uploads/{uploadId}/parts/{partNumber}
GET  /api/v1/evidence-uploads/{uploadId}
POST /api/v1/evidence-uploads/{uploadId}/complete
```

Requisitos del contrato:

- aceptar `clientOperationId`/ID cliente o devolver mapping estable;
- idempotency key persistida en servidor y respuesta reproducible;
- cursor monotónico con tombstones y cambios de permisos;
- `version`/ETag para mutaciones;
- upload FCE por chunks reanudables con checksum por parte y SHA-256 final;
- receipt firmado o verificable con `msFileId`, hash, tamaño y timestamps;
- creación de sesión antes de aceptar evidencia ligada a esa sesión;
- auditoría append-only server-side;
- endpoint de estado para reachability sin depender de servicios públicos;
- códigos de error estables (`AUTH_EXPIRED`, `ACCESS_REVOKED`,
  `VERSION_CONFLICT`, `HASH_MISMATCH`, `QUOTA_EXCEEDED`, etc.).

Mientras el backend conserve solo multipart completo, la primera versión puede
reintentar fotos/documentos pequeños desde cero, pero videos grandes no cumplen
el gate de reanudación y no deben considerarse cerrados para producción offline.

## 8. Autenticación, autorización y aislamiento

### 8.1 Acceso offline

Agregar un estado de sesión explícito:

```text
unknown
unauthenticated
onlineAuthenticated
offlineAuthenticated
offlineAccessExpired
```

Política propuesta, a aprobar por seguridad institucional:

- el primer login siempre es online;
- al autenticar online se emite un permiso local con `accountId`, dispositivo,
  roles/permisos, hora de última verificación y expiración offline;
- la vigencia offline debe ser configurable (por ejemplo 24–72 horas), no
  infinita ni deducida solo de la expiración del access token;
- reabrir offline usa perfil y permiso local cifrados;
- una conexión fallida no cierra sesión ni borra tokens/datos;
- un 401/403 confirmado por el backend sí cambia el estado correspondiente;
- al vencer la ventana offline, la evidencia pendiente permanece cifrada pero la
  UI exige reconectar/autenticar antes de mostrar datos sensibles.

### 8.2 Cambio de usuario y logout

- todas las filas, archivos y operaciones llevan `accountId`;
- otra cuenta nunca puede consultar los datos de la anterior;
- logout remoto es best-effort, pero logout local no elimina evidencia pendiente;
- si hay pendientes, mostrar cantidad/tamaño y pedir conservar/bloquear el
  perfil o cancelar el logout;
- un administrador puede aplicar una política de borrado solo después de backup,
  receipt y auditoría aprobados;
- una desinstalación continúa siendo una pérdida local: la recuperación depende
  de que ciphertext y envoltura institucional ya existan en backend.

### 8.3 Revocación de acceso

La operación offline usa el último permiso conocido, por lo que existe una
ventana de revocación inevitable. Al reconectar:

- sincronizar permisos antes de subir;
- si la requisa fue revocada, no abrir nuevas envolturas ni subir a destinatarios
  antiguos;
- conservar la adquisición en cuarentena cifrada;
- registrar evento y requerir decisión institucional para reasignar/exportar;
- nunca mover silenciosamente evidencia a otra requisa.

## 9. UX y comportamiento responsive

### 9.1 Indicador global

Implementar `AppConnectivityBanner` en el `builder` de `MaterialApp.router`, por
encima del `Navigator`, para cubrir login, listado, detalle, conexión, mirror,
transferencia y modales. No crear un segundo shell de navegación.

Comportamiento implementado:

- **compact `<600`**: píldora flotante centrada, de una línea y ancho intrínseco;
- **medium/expanded/large `>=600`**: píldora flotante alineada al borde seguro;
- se posiciona debajo de la altura estándar del `AppBar`, sin reservar una fila
  ni interceptar el resto de la pantalla;
- respetar `SafeArea`, text scaling, teclado, 48 dp de target, mouse, foco y
  semántica accesible;
- usar `Theme.of(context)` y colores semánticos mediante `ColorScheme` o una
  `ThemeExtension`; no definir una paleta privada;
- el indicador no cambia el árbol por orientación o tipo de equipo.

Estados y textos:

```text
Sin conexión
Sin conexión al servidor
```

Los estados `online` y `checking` no renderizan badge.

Al tocarlo se abre un `AppModalBottomSheet` responsive con:

- estado del backend y última sincronización;
- número/tamaño de operaciones pendientes;
- evidencia actual y progreso;
- errores clasificados sin datos sensibles;
- acciones **Reintentar ahora**, **Pausar**, **Ver pendientes**;
- explicación de que cerrar la app no elimina las evidencias.

### 9.2 Listado

Agregar fase `offlineContent` o, preferiblemente, campos ortogonales
`dataSource`, `isStale`, `lastSyncedAt` al estado Freezed. Nunca mostrar error a
pantalla completa si existen datos locales.

- cache vacío + offline: estado vacío explicativo “Aún no hay requisas
  disponibles en este dispositivo”, no “error de servidor”;
- cache con datos + offline: lista/grid/tabla habitual con sello “última
  actualización”;
- búsqueda, estado y fechas operan localmente;
- refresh offline conserva contenido y explica que se actualizará al reconectar;
- cada requisa muestra `Completa offline`, `Parcial` o `Solo metadata` cuando
  corresponda.

### 9.3 Detalle y evidencias

- renderizar cabecera, sujetos, permisos, sesiones e inventario desde snapshot;
- diferenciar **Copia local**, **Pendiente de subir**, **En servidor**,
  **No disponible offline** y **Error**;
- preview nunca intenta red si el monitor ya sabe que está offline; muestra una
  acción clara para preparar al reconectar;
- una evidencia creada offline aparece inmediatamente con su hash y estado;
- el botón de adquisición sigue activo con permiso cacheado y requisa editable;
- las acciones que exigen autorización fresca quedan deshabilitadas con motivo;
- la tarjeta actual “Sincronizar para uso offline” pasa a representar readiness
  del inventario, no el estado de conexión de la app.

### 9.4 Mirror individual y múltiple

- conservar workspace y controles existentes;
- mostrar el indicador global sin cubrir textura, barra de captura o targets
  táctiles;
- persistir la sesión/fuente antes de conectar ADB;
- mostrar “Guardado localmente” al capturar/grabar offline;
- el contador de pendientes se actualiza desde SQLCipher;
- cada fuente multi conserva `sourceLocalId`, modelo/fingerprint y sujeto elegido
  en la evidencia/ledger;
- desconectar una fuente no altera las demás ni invalida las evidencias creadas;
- salir del mirror cierra recursos nativos y deja la sesión local lista para
  completar/sincronizar.

## 10. Navegación

- mantener `MaterialApp.router` y el router central;
- conservar `requisitionId` y `sessionId` en path parameters;
- permitir que `sessionId` sea el UUID local estable;
- no crear rutas especiales `/offline/...`; las mismas rutas funcionan con la
  fuente local;
- `extra` sigue transportando textura/handles efímeros, pero nunca el único ID;
- si se restaura una ruta de mirror tras muerte de proceso, mostrar fallback
  visible para reconectar; no fingir que la textura sobrevivió;
- el guard central acepta `offlineAuthenticated` mientras la política local sea
  válida;
- `/offline` puede convertirse en una ayuda/diagnóstico, pero no en redirect
  obligatorio.

No se necesita `StatefulShellRoute`: el badge vive en la raíz visual y no existe
navegación persistente por ramas que lo justifique.

## 11. Preparación de evidencias remotas para uso offline

Para “ver mis evidencias offline” se necesitan metadata y FCE, no solo tarjetas.
Definir tres niveles por requisa:

```text
METADATA_ONLY   # cabecera e inventario; preview remoto no garantizado
PARTIAL         # algunas copias FCE verificadas
COMPLETE        # todas las evidencias elegibles disponibles y verificadas
```

Política recomendada:

- sincronizar siempre metadata de requisas asignadas;
- preparar automáticamente thumbnails no sensibles cuando la política lo
  permita;
- permitir **Preparar requisa para trabajo offline** con estimación de tamaño;
- opcionalmente auto-preparar requisas activas con Wi-Fi/carga y cuota suficiente;
- verificar hash FCE y contenido plano antes de marcar `COMPLETE`;
- no marcar una requisa completa si una evidencia falló o fue omitida por espacio;
- permitir elegir evidencias si el total excede la cuota.

## 12. Almacenamiento, cuotas y retención

Antes de mirror, grabación, transferencia, importación o descarga:

- consultar espacio disponible;
- reservar margen para `.part`, FCE, DB, thumbnails y cierre del MP4;
- mostrar estimación de grabación según bitrate;
- impedir iniciar si no se puede garantizar el mínimo configurado;
- durante una grabación, avisar y detener/cerrar limpiamente antes del agotamiento;
- no contar cache/thumbnails como evidencia original.

Política de limpieza:

1. temporales de preview y `.part` vencidos;
2. thumbnails regenerables;
3. FCE remotos ya verificados, solo con receipt y según retención aprobada;
4. nunca evidencia `LOCAL_ONLY`, pendiente, con error de integridad o sin receipt.

El usuario debe ver espacio usado por pendientes, copias offline y derivados.

## 13. Fases de implementación

### Fase 0 — contrato, ADR y políticas

- aprobar vigencia de sesión offline, revocación, retención y cuota;
- acordar IDs cliente, cursor, versiones, tombstones, receipts y chunks con backend;
- documentar máquina de estados y códigos de error;
- definir fixtures y matriz de interrupciones.

**Salida:** ADR y contrato API aprobados; no comenzar sincronización general sin
idempotencia server-side.

### Fase 1 — base local, cuenta y migraciones

- ampliar SQLCipher con cuenta, requisas, sesiones, fuentes, sync operations,
  cursors y ledger;
- migrar evidencia v7 sin pérdida;
- implementar cuarentena de filas no atribuibles;
- separar fachadas de acceso sin duplicar el archivo de base;
- registrar dependencias por `provider`.

**Salida:** reiniciar proceso conserva una requisa fixture, detalle, sesión y FCE;
otra cuenta no puede leerlos.

### Fase 2 — conectividad, autenticación y badge global

- reemplazar el checker público por reachability institucional;
- implementar estado global y `offlineAuthenticated`;
- agregar banner/bottom sheet responsive en `App.builder`;
- evitar logout por fallos transitorios;
- convertir `/offline` en diagnóstico no bloqueante.

**Salida:** airplane, Wi-Fi sin internet, backend caído y reconexión producen
estados correctos sin perder navegación.

### Fase 3 — requisas y detalle offline-first

- crear servicios locales y repositorios compuestos;
- persistir bootstrap/listado/detalle/versiones/tombstones;
- ejecutar búsqueda/filtros locales;
- reemplazar el `Map` de detalle como fuente principal;
- implementar readiness de evidencias.

**Salida:** login previo -> matar app -> airplane -> abrir lista/detalle/preview
preparado.

### Fase 4 — sesión local y adquisición offline

- crear `StartAcquisitionSessionUseCase`;
- usar UUID local en rutas y carpetas;
- persistir fuentes individual/múltiple;
- adaptar importación, mirror y transferencia para no llamar HTTP antes;
- registrar evidencia/ledger/outbox atómicamente;
- persistir cierre de sesión local.

**Salida:** mirror individual y 1/2/3 fuentes crean capturas y videos offline y
los conservan después de reiniciar.

### Fase 5 — sincronización dependiente e idempotente

- implementar grafo de operaciones y claims compartidos;
- sincronizar permisos y sesiones antes de evidencias;
- mappings local/remoto;
- key envelopes con autorización vigente;
- uploads reanudables y receipts;
- conflictos, backoff, pausa, reintento y acción requerida;
- completar sesiones y opcionalmente finalizar después de toda evidencia.

**Salida:** repetir, matar y reanudar la sincronización no duplica sesiones,
evidencias ni eventos.

### Fase 6 — cuotas, recuperación y endurecimiento probatorio

- preflight de espacio y límites de grabación/lotes;
- barrido de temporales y recuperación de crash;
- ledger append-only completo;
- telemetría segura/códigos estables;
- política de logout, revocación y retención;
- revisión criptográfica y threat model.

**Salida:** fallas de disco, cable, proceso, auth e integridad terminan en estado
recuperable y auditable.

### Fase 7 — validación y piloto

- unit/widget/integration/native/protocol/soak;
- matriz física de hardware;
- upgrade desde DB v7 con evidencia real;
- piloto acotado a modelos y versiones homologados;
- manual operativo offline/reconexión.

**Salida:** aprobación formal limitada a la matriz validada.

## 14. Mapa de cambios por archivo/vertical

### Archivos existentes a evolucionar

- `lib/app.dart`: montar indicador global sin navegación paralela.
- `lib/core/di/dependency_injection.dart`: registrar conectividad, DB local,
  repositorios offline-first y sync coordinator.
- `lib/data/datasources/remote/internet_checker.dart`: retirar DNS/Google como
  criterio de backend.
- `lib/domain/repositories/connectivity_repository.dart`: corregir nombre y
  exponer stream/estado de dominio.
- `lib/data/repositories/connectivity_repository_impl.dart`: combinar enlace,
  health, auth y sincronización.
- `lib/data/services/local_evidence_database_service.dart`: migrar preservando
  FCE y extraer fachadas por agregado.
- `lib/data/repositories/remote_requisition_repository.dart`: convertir en
  repositorio offline-first o retirarlo después de migrar consumidores.
- `lib/data/repositories/remote_requisition_detail_repository.dart`: persistir
  detalle y eliminar dependencia del cache solo en memoria.
- `lib/data/services/evidence_sync_service.dart`: consumir operaciones
  dependientes, uploads reanudables y receipts.
- `lib/data/services/evidence_background_sync_service.dart`: ejecutar el mismo
  coordinador y no crear una segunda lógica de sync.
- `lib/ui/features/auth/session/auth_session_controller.dart`: estado offline y
  política de vigencia.
- `lib/ui/features/requisitions/list/`: snapshot local, stale/readiness y refresh.
- `lib/ui/features/requisitions/detail/`: sesión local, capacidades offline y
  estados explícitos.
- `lib/data/repositories/acquisition_repository_impl.dart`: atribución de fuente,
  registro atómico y sync no bloqueante.
- `lib/ui/features/acquisition/mirror/`: feedback local y fuente persistida, sin
  cambiar identidad visual.
- `lib/ui/core/navigation/`: admitir IDs locales y fallback de handles efímeros.

### Estructura nueva sugerida

```text
lib/domain/models/
├── connectivity_state.dart
├── offline_access.dart
├── local_acquisition_session.dart
├── sync_operation.dart
└── custody_event.dart

lib/domain/repositories/
├── local_session_repository.dart
├── sync_repository.dart
└── custody_ledger_repository.dart

lib/domain/usecases/offline/
├── restore_offline_session.dart
├── start_local_acquisition_session.dart
├── register_evidence_atomically.dart
└── synchronize_offline_work.dart

lib/data/services/database/
├── file_cast_local_database_service.dart
├── migrations/
├── local_requisition_service.dart
├── local_session_service.dart
├── local_sync_operation_service.dart
└── local_custody_ledger_service.dart

lib/data/repositories/
├── offline_first_requisition_repository.dart
├── offline_first_requisition_detail_repository.dart
├── local_session_repository_impl.dart
└── sync_repository_impl.dart

lib/ui/features/connectivity/
├── view_models/connectivity_view_model.dart
└── widgets/
    ├── app_connectivity_banner.dart
    └── sync_status_sheet.dart
```

Los nombres pueden ajustarse durante implementación, pero deben conservar la
separación `View -> ViewModel -> UseCase opcional -> Repository -> Service`.

## 15. Estrategia de pruebas y matriz de fallas

Las siguientes pruebas son criterios para el propietario/CI; este plan no las
ejecuta.

### 15.1 Sesión y navegación

- instalación nueva offline: explica que el primer acceso requiere red;
- login online, cerrar proceso, airplane, cold start: entra como sesión offline;
- vencimiento de política offline: bloquea lectura sensible sin borrar pendientes;
- red intermitente durante restore: no redirige erróneamente a login;
- notificación abre detalle cacheado con la ruta correcta;
- cambio de cuenta: cero filas/archivos visibles de otra cuenta.

### 15.2 Requisas y evidencias

- listado/detalle cacheado tras process death y reinicio del dispositivo;
- filtros locales equivalentes a online;
- requisa metadata-only/parcial/completa;
- preview local con FCE íntegro, corrupto, ausente y sin envoltura;
- tombstone y acceso revocado;
- migración v7 con evidencias pendientes, sincronizadas y errores.

### 15.3 Adquisición offline

- mirror individual offline: 100 capturas y grabación de 30 minutos;
- multi mirror offline: 1/2/3 fuentes ORICO, captura/grabación por fuente;
- detach/reconnect de una fuente sin afectar las demás;
- transferencia de 0 B, 1 MB, 1 GB, unicode y nombres hostiles;
- cierre de app durante `.part`, cifrado, transacción y thumbnail;
- poco espacio antes y durante grabación;
- reloj cambiado durante adquisición: UTC + monotónico conservan orden.

### 15.4 Sincronización

- reconectar con 1, 100 y lotes grandes de evidencias;
- cerrar proceso en cada paso sesión/intento/chunk/complete/receipt;
- repetir la misma operación/idempotency key;
- 401 con refresh válido e inválido;
- 403 por acceso revocado;
- 409/412 por versión;
- 413/cuota, 429/retry-after, 5xx y timeout;
- hash incorrecto local, por parte y final;
- worker y UI intentando sincronizar al mismo tiempo;
- pausa/reanudación y red que oscila rápidamente;
- verificar que no existe duplicado en DB, file-cast-back ni ms-files-v2.

### 15.5 UI adaptive

- compact, medium, expanded y large;
- altura menor a 480;
- text scale alto y textos largos;
- teclado, mouse/trackpad y foco;
- banner con AppBar, modal, teclado, mirror y multi mirror;
- temas claro/oscuro y contraste;
- cero contenido o controles cubiertos por el indicador.

## 16. Gates de aceptación

### Gate A — lectura offline

- cold start sin internet muestra requisas asignadas y su detalle persistido;
- no depende de memoria del proceso;
- preview funciona para toda evidencia marcada `COMPLETE`;
- otra cuenta no accede a esos datos.

### Gate B — adquisición offline

- sesión local se crea sin HTTP;
- mirror individual y múltiple operan con IDs locales;
- cada evidencia queda FCE, hash, metadata, fuente, ledger y outbox;
- matar/reiniciar no pierde ni duplica evidencia.

### Gate C — sincronización

- sesión remota se crea antes de evidencia;
- reintentos son idempotentes;
- videos grandes reanudan por chunks;
- el servidor confirma hash/receipt;
- los estados locales solo pasan a `SYNCED` tras confirmación.

### Gate D — seguridad y custodia

- SQLCipher/FCE y claves funcionan después de upgrade;
- permisos/revocaciones se reconcilian antes de subir;
- no hay plaintext persistente ni datos sensibles en logs/notificaciones;
- ledger local/server permite verificar orden e integridad;
- ninguna limpieza borra evidencia sin receipt/política.

### Gate E — operación

- badge correcto y visible en todas las pantallas;
- pendientes, errores y acción requerida son comprensibles;
- cuotas y poco espacio se detectan antes de pérdida;
- matriz física y soak tests aprobados para el piloto.

## 17. Definition of Done

El modo offline no se considera terminado hasta cumplir todo lo siguiente:

- sesión offline con política aprobada y aislamiento por cuenta;
- listado/detalle persistidos con versiones, tombstones y stale state;
- evidencia remota preparada/verificada según readiness visible;
- sesión de adquisición local independiente de red;
- mirror individual/múltiple, captura, grabación, transferencia e importación
  funcionando offline;
- registro atómico FCE + Evidence + CustodyEvent + SyncOperation;
- sincronización dependiente, idempotente, reanudable y con receipts;
- resolución explícita de auth, permisos, conflictos, integridad y cuota;
- recuperación ante process death, reinicio, detach y almacenamiento insuficiente;
- badge global responsive, accesible y no invasivo;
- documentación de backend, migraciones, operación, retención y soporte;
- validación automatizada y física ejecutada por el propietario/CI;
- cero deuda crítica abierta para pérdida, duplicación, atribución o exposición de
  evidencia.

## 18. Orden inmediato recomendado

1. Aprobar las políticas de acceso offline, revocación, cuota y retención.
2. Cerrar el contrato backend de IDs cliente, sync cursor, versiones, chunks y
   receipts.
3. Diseñar y revisar la migración SQLCipher v7 antes de tocar Views.
4. Implementar cuenta/conectividad/badge y cache persistente de requisas/detalle.
5. Sustituir la creación remota previa de sesión por sesión local + outbox.
6. Unificar captura/importación/transferencia en registro atómico con fuente y
   ledger.
7. Implementar sincronización por dependencias y validar idempotencia.
8. Ejecutar la matriz offline individual/múltiple, interrupciones y migración.

Este orden entrega valor verificable por vertical y evita construir una UI
“offline” sobre repositorios que todavía dependen del backend.
