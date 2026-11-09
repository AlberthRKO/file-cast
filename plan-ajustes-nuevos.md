# Plan de ajustes nuevos: CUD, sujetos procesales y evidencias

Fecha de elaboración: 9 de noviembre de 2026
Repositorios revisados:

- Aplicación Flutter: `/Volumes/ALBERTH_MAC_EXT/fiscalia/apps/file_cast`
- Backend NestJS/Prisma: `/Volumes/ALBERTH_MAC_EXT/fiscalia/file-cast-back`

## 1. Objetivo

Implementar de extremo a extremo estas capacidades:

1. Una requisa creada por persona solo podrá vincularse a un CUD si esa persona figura, con identidad verificable, entre los sujetos procesales del caso.
2. Cada evidencia podrá quedar relacionada con cero, uno o varios sujetos procesales del CUD actual.
3. Las evidencias de una requisa cuyo origen sea una persona quedarán automáticamente relacionadas con su sujeto principal.
4. El detalle de la requisa mostrará los sujetos relacionados con cada evidencia y permitirá modificar la selección desde el menú de tres puntos.
5. Una evidencia tendrá un nombre visible editable sin alterar el nombre original, el archivo probatorio, sus hashes ni el objeto almacenado en `ms-files-v2`.
6. El detalle y el mirror permitirán renombrar la evidencia; el mirror mostrará un icono de edición junto al nombre.
7. El detalle de la requisa conservará y mostrará la lista completa de sujetos procesales del CUD, usando la información estructurada de cada elemento de `suprCasosPersonas`.

Este documento es únicamente un plan. No implementa todavía migraciones, endpoints ni UI.

## 2. Estado actual confirmado

### Backend

- `RequisitionSubject` guarda la persona con la que nació una requisa `PERSON`, pero los sujetos de una requisa creada o vinculada a un caso no se normalizan en esa tabla.
- Los sujetos del CUD llegan desde el cliente dentro de `RequisitionCase.snapshot` y actualmente suelen reducirse a una lista de nombres.
- `POST /api/v1/requisitions/:id/case-links` confía en el `snapshot` enviado por la aplicación y no vuelve a consultar el caso en la fuente interna.
- El enlace a CUD no compara la persona principal de la requisa con los sujetos procesales del caso.
- El contrato real revisado contiene dos IDs diferentes que hoy no se preservan correctamente: `suprCasosPersonas[].id`, que identifica la participación procesal dentro del caso, y `suprCasosPersonas[].suprPersona.id`, que identifica a la persona y coincide con `persona/buscar.segipPersonaId`. Solo este último será la clave de anclaje de evidencias.
- `Evidence` no tiene relación con sujetos procesales.
- El nombre mostrado proviene de `File.originalName`. Modificarlo destruiría la distinción entre el nombre original adquirido y una etiqueta posterior del operador.
- No existen endpoints para renombrar una evidencia ni para actualizar sus sujetos.

### Aplicación Flutter

- `EcosystemCaseSummary.subjects` y `EcosystemCaseDto.subjects` son `List<String>`; se pierde el ID externo, CI y rol de cada sujeto.
- El parser actual toma principalmente una etiqueta de nombre y descarta `situacionJuridicaId`, `reservaIdentidad`, `suprPersona`, `suprEntidadJuridica`, `suprTipoSujeto` y `actualEstadoSujeto`.
- `RequisitionSubjectSummary` tampoco conserva el UUID local del sujeto, dato necesario para enviar una selección segura al backend.
- `RequisitionEvidence` solo expone `name`; no distingue `originalName` de `displayName` ni contiene sujetos relacionados.
- El menú de tres puntos del detalle ofrece actualmente `Cargar` y `Eliminar` según el estado.
- Los cards del detalle muestran peso, estado y sincronización, pero no sujetos relacionados.
- Los cards del mirror muestran el nombre y estado, sin acción de edición.
- SQLite conserva `nombre_original`, pero no un nombre visible ni una selección local de sujetos para evidencias todavía pendientes de subida.

## 3. Decisiones de diseño

### 3.1 El backend será la autoridad del vínculo con el CUD

La aplicación enviará el identificador externo y/o CUD seleccionado. El backend consultará el gateway interno, resolverá un único caso exacto y construirá su propio snapshot tipado. El cliente no será fuente de verdad para decidir qué personas pertenecen al caso.

La consulta externa debe ejecutarse antes de abrir una transacción Prisma. La transacción solo persistirá el caso ya resuelto, sus sujetos y el evento de custodia.

### 3.2 Diferenciar persona SEGIP de sujeto procesal

El log real confirma esta estructura:

```text
persona buscada:
  segipPersonaId = 1339

elemento del caso:
  suprCasosPersonas.id = 2626
  suprCasosPersonas.suprPersona.id = 1339
```

Por tanto existen dos identificadores relacionados, pero no intercambiables:

- `suprPersona.id` es el ID común de persona y coincide con `segipPersonaId`; se utilizará tanto para validar la pertenencia al CUD como para anclar evidencias.
- `suprCasosPersonas.id` identifica el registro o participación del sujeto dentro de ese caso. Se conservará como metadata del caso, pero nunca será la clave del anclaje de una evidencia.

| Dato | Valor del ejemplo | Uso |
|---|---:|---|
| `persona/buscar.segipPersonaId` | 1339 | `personaId` de la requisa personal y anclaje automático de sus evidencias |
| `suprCasosPersonas[].suprPersona.id` | 1339 | El mismo `personaId`: validar pertenencia y anclar evidencias de una requisa por CUD |
| `suprCasosPersonas[].id` | 2626 | Metadata de la participación procesal en ese caso; no se usa para anclar |

La validación principal será:

```text
RequisitionSubject.personId
  == suprCasosPersonas[].suprPersona.id
  == persona/buscar.segipPersonaId
```

El número de documento normalizado quedará como comprobación secundaria defensiva. No se aceptará coincidencia por nombre, alias o similitud textual. Si ningún elemento cumple la igualdad del ID de persona, el backend devolverá `REQUISITION_SUBJECT_NOT_IN_CASE` y no persistirá el vínculo.

Los elementos representados por `suprEntidadJuridica` y sin `suprPersona.id` deben persistirse y verse en la lista completa del detalle. No serán seleccionables para anclaje de evidencia bajo este contrato, porque no tienen el `personaId` común exigido. Si en el futuro se requiere anclar entidades jurídicas, se diseñará un identificador y contrato separados, sin reutilizar `suprCasosPersonas.id` como si fuera un `personaId`.

### 3.3 Los sujetos serán entidades estables de la requisa

`RequisitionSubject` representará una persona estable de la requisa, identificada externamente por el `personaId` común (`segipPersonaId`/`suprPersona.id`). `RequisitionCaseSubject` representará la participación procesal concreta devuelta en `suprCasosPersonas`, incluyendo su ID exterior y su información completa. No se dejará esta información únicamente dentro de un JSON sin proyección tipada.

Esto permite:

- conservar el sujeto original de una requisa por persona, con `personId = segipPersonaId`;
- reutilizar ese mismo sujeto cuando `suprPersona.id` aparezca en el CUD;
- persistir todos los sujetos del caso;
- conservar el historial si el CUD actual se reemplaza;
- relacionar una evidencia con una o varias personas mediante sus `personaId`, independientemente del ID de participación que tengan en un caso concreto.

### 3.4 El anclaje de evidencia será muchos-a-muchos y auditable

Una evidencia podrá tener varias personas ancladas y una persona podrá aparecer en varias evidencias. Los cambios de selección conservarán historial de alta y baja; no se borrarán silenciosamente las relaciones anteriores. La selección pública usará siempre `personaId`, cuyo valor proviene de `segipPersonaId` o de `suprPersona.id` según el flujo.

Reglas de producto:

- Requisa de origen `CASE`: el conjunto puede estar vacío.
- Requisa de origen `PERSON`: el `segipPersonaId` principal se agrega automáticamente a toda evidencia y no se puede retirar; después de vincular el CUD se podrán agregar otras personas del caso.
- La selección manual solo ofrecerá elementos del CUD actual que tengan `suprPersona.id`.
- El backend validará pertenencia aunque la aplicación haya filtrado correctamente la lista.
- Una requisa sellada, cancelada o en finalización no permitirá renombrar ni cambiar sujetos.

### 3.5 Renombrar no modificará el archivo original

Se agregará `Evidence.displayName` como etiqueta editable. Se mantendrán sin cambios:

- `File.originalName`;
- la ruta y el nombre del contenedor FCE;
- el archivo de `ms-files-v2`;
- MIME, extensión, tamaños y hashes;
- AAD y material de cifrado ya generado.

La aplicación mostrará `displayName ?? originalName`. Así el operador puede usar un nombre descriptivo sin alterar la evidencia adquirida.

## 4. Modelo de datos propuesto

### 4.1 Cambios a sujetos

Actualizar `RequisitionSubject`:

- conservar `personId = segipPersonaId` para la persona que originó la requisa y usar el mismo campo para los `suprPersona.id` importados desde el CUD;
- agregar unicidad por `requisitionId + personId`, de modo que una misma persona tenga una sola identidad estable dentro de la requisa aunque figure en más de una participación procesal;
- permitir `documentNumber` nullable para identidades que legítimamente no tengan documento disponible;
- agregar `normalizedDocumentNumber` nullable para comparación técnica, sin reemplazar el valor original;
- conservar `fullName`, `isPrimary` y el snapshot;
- agregar relaciones hacia casos y evidencias.

Crear `RequisitionCaseSubject`:

```text
id                         UUID PK
caseLinkId                 UUID FK -> RequisitionCase
requisitionSubjectId       UUID FK -> RequisitionSubject nullable
externalCaseSubjectId      INTEGER  # suprCasosPersonas.id
personId                   INTEGER nullable  # suprPersona.id, coincide con RequisitionSubject.personId
legalSituationId           INTEGER nullable
alias                      VARCHAR nullable
identityReserved           BOOLEAN
personFullName             VARCHAR nullable
personDocumentNumber       VARCHAR nullable
legalEntitySnapshot        JSONB nullable
subjectTypeId              INTEGER nullable
subjectTypeName            VARCHAR nullable
subjectTypeColorHex        VARCHAR nullable
subjectTypeLevel           INTEGER nullable
currentSubjectState        JSONB nullable
snapshot                   JSONB NOT NULL  # elemento completo de suprCasosPersonas
createdAt                  TIMESTAMPTZ
createdBy                  VARCHAR
UK                         (caseLinkId, externalCaseSubjectId)
```

Esta tabla separa la identidad de persona de la participación procesal concreta. `requisitionSubjectId` enlaza a la persona estable cuando `personId = suprPersona.id`; para la persona principal coincide además con `segipPersonaId`. Puede ser nulo para una entidad jurídica o para registros que no tengan persona natural asociada.

Se guardarán columnas tipadas para búsqueda, validación y UI, además del elemento completo en `snapshot` para no perder campos que el gateway agregue o que todavía no tengan una proyección propia.

### 4.2 Relación evidencia-sujeto

Crear `EvidenceSubjectLink`:

```text
id               UUID PK
evidenceId       UUID FK -> Evidence
requisitionSubjectId UUID FK -> RequisitionSubject
source           AUTO_PERSON | MANUAL
linkedAt         TIMESTAMPTZ
linkedBy         VARCHAR
unlinkedAt       TIMESTAMPTZ nullable
unlinkedBy       VARCHAR nullable
```

Agregar:

- índice de consulta por `evidenceId, unlinkedAt`;
- índice por `requisitionSubjectId, unlinkedAt`;
- índice único parcial para impedir dos vínculos activos del mismo par `evidenceId + requisitionSubjectId`;
- validación de que la evidencia y la persona pertenezcan a la misma requisa;
- para vínculos manuales, validación adicional de que `RequisitionSubject.personId` aparezca como `RequisitionCaseSubject.personId` en el CUD actual.

Las evidencias creadas en una requisa `PERSON` antes de existir CUD se anclarán inmediatamente al `RequisitionSubject` cuyo `personId = segipPersonaId`. Al vincular el CUD, la transacción comprobará `segipPersonaId == suprPersona.id` y asociará a ese mismo `RequisitionSubject` la metadata de `RequisitionCaseSubject`; el vínculo de evidencia no cambia ni se migra porque ya usa el ID común de persona. No se perderán evidencias previas ni se escogerá un sujeto por nombre.

### 4.3 Nombre visible y auditoría

Agregar a `Evidence`:

```text
displayName      VARCHAR(255) nullable
updatedAt        TIMESTAMPTZ
updatedBy        VARCHAR nullable
```

Agregar a `CustodyEventType`:

- `EVIDENCE_RENAMED`;
- `EVIDENCE_SUBJECTS_UPDATED`.

El payload del evento de renombre registrará nombre anterior y nuevo. El evento de sujetos registrará los IDs agregados y retirados. No se incluirán cuerpos de archivo, claves ni información innecesaria.

### 4.4 Migración y datos existentes

Crear una migración Prisma versionada; no usar `prisma db push` ni editar `src/generated` manualmente.

Pasos de migración:

1. crear columnas y tablas nuevas sin eliminar datos actuales;
2. normalizar el documento de los `RequisitionSubject` existentes;
3. dejar `displayName = NULL`, para que toda evidencia conserve inicialmente su nombre original;
4. intentar backfill de sujetos de caso únicamente cuando el snapshot contenga `suprCasosPersonas` estructurado, conservando `suprCasosPersonas.id` como metadata y usando `suprPersona.id` como `personId` del anclaje;
5. no crear identidades por comparación de nombres para snapshots históricos que solo tengan texto;
6. preparar una tarea controlada de rehidratación desde el gateway interno para CUD históricos;
7. mientras una requisa histórica no tenga sujetos rehidratados, ocultar o deshabilitar el selector con un mensaje explícito, sin inventar opciones.

Actualizar también `docs/requisitions/DATABASE.md`, `DATABASE-DIAGRAM.md`, `IMPLEMENTATION-PLAN.md` y el Swagger del backend.

## 5. Backend: contratos y servicios

### 5.1 Tipar la respuesta de casos

En `src/modules/file-cast/`:

- sustituir el uso interno de `unknown[]` por contratos tipados de caso y sujeto;
- crear un adaptador cuyo origen canónico sea `suprCasosPersonas`;
- mapear `suprCasosPersonas.id` como `externalCaseSubjectId`;
- mapear `suprCasosPersonas.suprPersona.id` como `personId`, compararlo con `segipPersonaId` y usarlo como clave de anclaje;
- mapear `suprPersona.nombreCompleto` y `suprPersona.ci` sin reemplazarlos por el alias;
- conservar `situacionJuridicaId`, `alias`, `reservaIdentidad`, `suprEntidadJuridica`, `suprTipoSujeto.id/nombre/colorHex/nivel`, `actualEstadoSujeto` y el item completo como snapshot;
- soportar sujetos de entidad jurídica aunque `suprPersona` sea nulo;
- añadir fixtures/contract tests con respuestas reales anonimizadas del gateway;
- exponer el puerto de consulta para que `RequisitionsService` pueda resolver un caso exacto sin duplicar HTTP.

`FileCastModule` deberá exportar el puerto o servicio requerido y `RequisitionsModule` importarlo. No se harán llamadas HTTP desde el repositorio Prisma.

### 5.2 Creación y vínculo de caso

Reutilizar un flujo común para:

- crear una requisa directamente desde un CUD;
- vincular posteriormente una requisa creada por persona.

Flujo propuesto:

1. autorizar al actor;
2. consultar el caso exacto por `externalCaseId` y/o `cud`;
3. rechazar cero resultados, resultados ambiguos o inconsistencias entre ID y CUD;
4. si el origen es `PERSON`, comparar `segipPersonaId` con cada `suprCasosPersonas[].suprPersona.id`;
5. normalizar todos los sujetos procesales;
6. abrir una transacción corta;
7. cerrar el vínculo de caso anterior y crear el nuevo;
8. crear o reutilizar un `RequisitionSubject` por cada `suprPersona.id`, usando ese valor como `personId` estable;
9. reutilizar el `RequisitionSubject` principal cuando `segipPersonaId = suprPersona.id`;
10. crear una fila `RequisitionCaseSubject` por cada elemento de `suprCasosPersonas`, conservando el ID exterior únicamente como identificador de participación procesal;
11. mantener sin cambios los anclajes automáticos previos, porque ya apuntan al `RequisitionSubject` del mismo `personId`;
12. incrementar la versión de la requisa y registrar `CASE_LINKED`.

El DTO de `POST /api/v1/requisitions/:id/case-links` quedará reducido conceptualmente a:

```json
{
  "externalCaseId": 123,
  "cud": "CUD-..."
}
```

Durante una ventana de compatibilidad puede aceptarse `snapshot`, pero debe ignorarse como autoridad y quedar marcado como deprecado.

El controller deberá pasar `requestId`, `correlationId` y `traceparent` al servicio para la llamada al gateway.

### 5.3 Endpoint para sujetos de una evidencia

Agregar:

```text
PUT /api/v1/requisitions/:id/evidences/:evidenceId/subjects
```

Body:

```json
{
  "personIds": [1339, 1637]
}
```

`personIds` contiene exclusivamente los valores de `suprCasosPersonas[].suprPersona.id`. Es el mismo espacio de identidad que `persona/buscar.segipPersonaId`; no contiene `suprCasosPersonas[].id` ni UUIDs internos de PostgreSQL.

Semántica: reemplazar el conjunto manual activo. Una lista vacía limpia los vínculos manuales; en una requisa `PERSON` el vínculo automático al `segipPersonaId` principal permanece.

Validaciones:

- máximo razonable de IDs y eliminación de duplicados;
- actor con acceso `OWNER` o `EDITOR`;
- requisa editable;
- evidencia existente, no eliminada y perteneciente a la requisa;
- cada `personId` aparece en `RequisitionCaseSubject.personId`, proveniente de `suprPersona.id`, para el CUD actual;
- no aceptar `suprCasosPersonas.id` como si fuera `personId`, ni personas de otro caso, de un CUD anterior o de otra requisa;
- operación transaccional e idempotente;
- incrementar versión/fecha de actualización de la requisa si ese es el mecanismo usado por sync;
- registrar el diff en `EVIDENCE_SUBJECTS_UPDATED`.

El repositorio no debe borrar filas históricas: marcará `unlinkedAt/unlinkedBy` y creará únicamente los vínculos faltantes.

### 5.4 Anclaje automático al crear evidencia

Dentro de la misma transacción de `createEvidenceIntent`:

- buscar la persona principal si `originType = PERSON`;
- crear el vínculo `AUTO_PERSON` directamente con el `RequisitionSubject.personId = segipPersonaId`, exista o no un CUD;
- si ya existe CUD, confirmar además que ese `personId` aparece como `RequisitionCaseSubject.personId`;
- aceptar opcionalmente `personIds` del cliente para una evidencia creada offline o para una requisa de origen `CASE`;
- validar esos IDs con las mismas reglas del endpoint;
- devolver la evidencia con sus sujetos ya resueltos.

La garantía debe estar en backend; no depender solamente de que Flutter preseleccione la persona.

### 5.5 Endpoint para renombrar

Agregar:

```text
PATCH /api/v1/requisitions/:id/evidences/:evidenceId/name
```

Body:

```json
{
  "displayName": "Fotografía ingreso principal"
}
```

Reglas:

- recortar espacios exteriores;
- exigir entre 1 y 255 caracteres útiles;
- rechazar caracteres de control;
- no interpretar el valor como ruta ni exigir que cambie la extensión;
- autorizar `OWNER` o `EDITOR`;
- bloquear estados no editables;
- no tocar `File.originalName` ni `ms-files-v2`;
- responder de forma idempotente si el nombre ya coincide;
- registrar `EVIDENCE_RENAMED` cuando exista un cambio real.

### 5.6 Respuestas de detalle y galería

Ampliar `RequisitionDetail` y `EvidenceSummary`:

```text
subject:
  personId = suprPersona.id
  caseSubjectId = suprCasosPersonas.id
  localId, legalSituationId?, alias?,
  identityReserved, personFullName?, personDocumentNumber?,
  legalEntity?, subjectType{id, name, colorHex, level},
  currentSubjectState?, isPrimaryPerson, isCurrentCaseSubject

evidence:
  originalName, displayName?, linkedSubjects[]
```

En el contrato público, `subject.personId` y `linkedSubjects[].personId` representarán `suprPersona.id`, coincidente con `segipPersonaId`; ese es el valor usado al listar, preseleccionar y actualizar anclajes. `caseSubjectId` expondrá opcionalmente `suprCasosPersonas.id` como metadata de la participación en el CUD. El UUID de PostgreSQL, si se expone, tendrá un nombre inequívoco como `localId`.

El detalle devolverá una colección `caseSubjects` completa derivada de todas las filas `RequisitionCaseSubject` del vínculo actual, no únicamente del sujeto principal. Cada item conservará los campos tipados y el snapshot estructurado.

La respuesta mantendrá `originalName` por compatibilidad y agregará `displayName`. La aplicación decidirá el nombre efectivo con fallback, sin que el backend reemplace semánticamente el original.

Los endpoints `GET /requisitions/:id` y `GET /requisitions/:id/evidences` deben usar la misma proyección para evitar diferencias entre detalle y galería.

Al sellar, el manifiesto debe incorporar el nombre visible y los sujetos activos, además de conservar hashes e IDs. La raíz de custodia ya reflejará los eventos de cambio.

### 5.7 Permisos

Agregar permisos explícitos, por ejemplo:

- `requisitions.evidence-update` para renombrar;
- `requisitions.evidence-subjects-update` para cambiar sujetos.

Registrar los códigos en `ms-auth` y aplicar `@RequirePermissions(...)`. La autorización por permiso no sustituye la verificación `OWNER/EDITOR` dentro de la requisa.

Evaluar `@Idempotent()` para ambos endpoints y requerir `Idempotency-Key` siguiendo el mecanismo actual.

## 6. Aplicación Flutter: dominio y datos

### 6.1 Modelos tipados

Reemplazar `List<String> subjects` en los modelos de casos por una lista tipada, por ejemplo:

```text
EcosystemSubjectSummary
  caseSubjectId  # suprCasosPersonas.id, solo metadata del caso
  personId?  # suprPersona.id, valor seleccionable para el anclaje
  legalSituationId?, alias, identityReserved,
  person{name, documentNumber}?, legalEntity?,
  subjectType{id, name, colorHex, level}?, currentSubjectState?
```

Renombrar el campo genérico `PersonSummary.id` a `segipPersonaId` —o exponer un getter con ese nombre durante la migración— para que la comparación no dependa de un `id` ambiguo.

Ampliar `RequisitionSubjectSummary` con:

```text
personId?, caseSubjectId, localId, legalSituationId?, alias?,
identityReserved, name?, documentNumber?, legalEntity?,
subjectType?, currentSubjectState?, isPrimaryPerson,
isCurrentCaseSubject
```

Ampliar `RequisitionEvidence` con:

```text
originalName, displayName?, linkedSubjects[]
effectiveName = displayName ?? originalName
```

Los nuevos modelos/snapshots deben ser inmutables y usar Freezed cuando corresponda. No se editarán archivos `*.freezed.dart` o `*.g.dart` a mano.

### 6.2 Servicios remotos

Actualizar:

- `RequisitionCreationService` y sus DTO para conservar la identidad completa de sujetos;
- `RequisitionService.linkCase` para enviar solo ID/CUD y dejar de enviar sujetos como fuente de verdad;
- `RequisitionDetailService` para parsear sujetos con UUID local, `displayName` y `linkedSubjects`;
- `RequisitionDetailRepository` con comandos `renameEvidence` y `setEvidenceSubjects`;
- `AcquisitionRepository` con la operación mínima necesaria para que `MirrorViewModel` pueda renombrar delegando al repositorio de detalle.

Crear métodos HTTP que consuman los dos nuevos endpoints y actualicen inmediatamente el snapshot cacheado tras una respuesta exitosa.

### 6.3 Persistencia local y sincronización

Incrementar la versión de `LocalEvidenceDatabaseService` mediante una migración idempotente.

Agregar a `evidencias_locales`:

```text
nombre_mostrado TEXT nullable
```

Agregar una tabla local para la selección deseada:

```text
evidencias_sujetos_locales
  evidencia_id, persona_id, origen, pendiente_sync, actualizado_at
```

`persona_id` guardará el entero común de `segipPersonaId`/`suprPersona.id`. `suprCasosPersonas.id` no se guardará en esta tabla de anclajes.

Comportamiento:

- una evidencia local nueva usa `originalName` como nombre inicial y `displayName = NULL`;
- en requisas `PERSON`, se inserta localmente el sujeto principal para reflejar la regla inmediatamente;
- renombrar una evidencia pendiente actualiza `nombre_mostrado`, no el nombre del FCE;
- seleccionar sujetos en una evidencia pendiente guarda la selección local;
- al crear la intención remota, `EvidenceSyncService` envía `displayName` y `personIds`;
- si la intención ya existe, la mutación se envía a los endpoints específicos;
- un fallo de red conserva el cambio como pendiente y no revierte la UI a un valor anterior;
- los cambios locales y remotos se mezclan por `evidenceId` sin duplicar evidencias.

Para mantener el comportamiento offline-first, ampliar la outbox o `SyncOperationType` con operaciones equivalentes a `RENAME_EVIDENCE` y `SET_EVIDENCE_SUBJECTS`. Cada operación debe llevar UUID estable, hash de payload y política de replay. Si se decide entregar primero una fase online, debe quedar explícitamente bloqueada la edición offline de evidencia ya sincronizada; no debe aparentar éxito sin persistencia.

### 6.4 ViewModels

`RequisitionDetailViewModel` añadirá:

- evidencia actualmente renombrándose/anclándose;
- comandos protegidos contra doble ejecución;
- validación local del nombre;
- apertura con selección inicial de sujetos;
- actualización optimista solo después de persistencia local segura;
- reconciliación con el snapshot remoto;
- mensajes específicos para persona no perteneciente al CUD, requisa sellada, sujeto inválido y fallo de red.

`MirrorViewModel` añadirá:

- `renameEvidence(evidence, displayName)`;
- estado ocupado por evidencia, sin bloquear captura o grabación de otras evidencias;
- actualización del listado reciente cuando cambie el cache/outbox.

La View no llamará HTTP, SQLite ni repositorios directamente.

## 7. Aplicación Flutter: experiencia de usuario

### 7.1 Vínculo de persona con CUD

En el modal existente de vínculo:

- mostrar los sujetos de cada candidato con su tipo, nombre/entidad y CI; `suprCasosPersonas.id` puede conservarse como metadata técnica, no como clave de comparación;
- prevalidar visualmente si `selectedPerson.segipPersonaId` coincide con algún `subject.personId` proveniente de `suprPersona.id`;
- deshabilitar la confirmación para un candidato claramente incompatible;
- conservar siempre la validación definitiva en backend;
- mostrar el mensaje del backend sin cerrar el modal si el vínculo es rechazado.

### 7.2 Lista completa de sujetos procesales en el detalle

La cabecera/resumen actual no debe reducir los sujetos a una lista de nombres. El detalle tendrá una acción `Sujetos procesales` que abra una hoja responsive con todos los elementos de `suprCasosPersonas` del CUD actual.

Cada card de sujeto mostrará, cuando el dato exista:

- nombre completo de `suprPersona` o denominación de `suprEntidadJuridica`;
- CI de `suprPersona.ci`;
- alias;
- tipo procesal de `suprTipoSujeto.nombre`;
- indicador visual con `suprTipoSujeto.colorHex`, validado antes de convertirlo a `Color`;
- nivel del tipo de sujeto;
- situación jurídica;
- estado actual del sujeto;
- aviso de identidad reservada, evitando exponer datos que la política institucional deba ocultar;
- identificador del sujeto procesal solo en vistas técnicas o de accesibilidad cuando sea necesario, no como texto principal.

La UI no mostrará `null`, mapas crudos ni JSON. `suprEntidadJuridica` y `actualEstadoSujeto` necesitarán DTOs tipados una vez que se obtengan ejemplos no nulos; mientras tanto se mostrará una etiqueta segura derivada por el adaptador y se conservará el snapshot completo.

En compact se usará `ListView.builder` dentro de un bottom sheet desplazable. En medium/expanded/large se usará una superficie centrada y limitada de ancho; si el volumen de sujetos es alto, se mantendrá renderizado lazy y búsqueda local por nombre, CI, alias o tipo.

### 7.3 Menú de tres puntos de la evidencia

Agregar opciones:

- `Cambiar nombre`;
- `Anclar a sujetos` cuando exista CUD actual y la requisa sea editable;
- conservar `Cargar` y `Eliminar` con sus reglas actuales.

El menú debe seguir visible aunque solo exista una acción de edición. Las acciones se deshabilitarán mientras esa misma evidencia esté subiendo o ejecutando otra mutación incompatible.

### 7.4 Modal para anclar sujetos

Crear un modal/bottom sheet responsive con:

- título y nombre efectivo de la evidencia;
- lista multiselección mediante checkboxes accesibles;
- nombre, CI, alias y tipo procesal de cada persona seleccionable;
- usar internamente `suprPersona.id` como `personId` de cada opción;
- selección actual precargada;
- sujeto principal marcado y bloqueado en requisas `PERSON`;
- excluir o mostrar deshabilitados los items de entidad jurídica que no tengan `suprPersona.id`, sin ocultarlos de la lista completa de sujetos procesales del detalle;
- estado vacío si el CUD no devuelve personas con `suprPersona.id` utilizables;
- botones `Cancelar` y `Anclar`;
- progreso, error y prevención de doble submit.

Aunque el requerimiento menciona un “select”, una lista de checkboxes es la representación más clara para una selección de uno o varios sujetos y mantiene targets táctiles de al menos 48 dp.

Responsive:

- compact: bottom sheet con altura controlada, lista desplazable y CTA respetando teclado/SafeArea;
- medium/expanded/large: superficie centrada y limitada por `AppSize.formMaxWidth` o token equivalente;
- altura menor a 480: encabezado compacto, contenido flexible y acciones siempre alcanzables;
- no cambiar el árbol por orientación ni tipo físico de dispositivo.

### 7.5 Información en el card

Debajo de la línea de peso y estado, cuando la requisa ya tenga CUD, mostrar:

- `Sujetos: Juan Pérez, Pedro López` si existen vínculos;
- `Sin sujetos anclados` si el conjunto opcional está vacío.

Para muchos sujetos, limitar visualmente la línea y usar `+N` o tooltip/semántica, sin perder la lista completa en el modal. No repetir IDs técnicos.

### 7.6 Modal de cambio de nombre

Crear un widget reutilizable por detalle y mirror, preferentemente en `lib/ui/features/evidence/widgets/`, porque ya existe un contrato común entre dos features.

Contenido:

- campo precargado con el nombre efectivo;
- contador/límite de 255 caracteres;
- validación de nombre vacío y caracteres de control;
- aclaración breve de que no cambia el archivo original;
- botones `Cancelar` y `Guardar`;
- progreso y error sin cerrar el modal.

No se requiere una ruta nueva; se reutilizarán diálogos o `showAppModalBottomSheet`.

### 7.7 Mirror

En `_EvidenceCard` del mirror:

- cambiar la fila del nombre a una composición `space-between`;
- usar `Expanded` para el texto truncado;
- agregar `IconButton` de edición con tooltip `Cambiar nombre` y target táctil accesible;
- abrir el mismo modal de renombre;
- conservar el badge de sincronización debajo;
- evitar que el botón tape el thumbnail o reduzca el nombre a un ancho inutilizable en el carrusel compacto.

No se modifica el protocolo ADB/scrcpy, la captura, el recorder ni el ciclo de vida del mirror.

## 8. Archivos principales previstos

### Backend

- `prisma/schema.prisma`
- nueva migración en `prisma/migrations/`
- `src/modules/file-cast/application/ports/file-cast.gateway.ts`
- `src/modules/file-cast/infrastructure/api-gw-interno-file-cast.client.ts`
- `src/modules/file-cast/file-cast.module.ts`
- `src/modules/requisitions/domain/requisition.ts`
- `src/modules/requisitions/application/ports/requisitions.repository.ts`
- `src/modules/requisitions/requisitions.service.ts`
- `src/modules/requisitions/infrastructure/persistence/prisma-requisitions.repository.ts`
- `src/modules/requisitions/presentation/http/dto/create-requisition.dto.ts`
- `src/modules/requisitions/presentation/http/dto/evidence.dto.ts`
- `src/modules/requisitions/presentation/http/requisitions.controller.ts`
- `src/modules/requisitions/requisitions.permissions.ts`
- documentación y pruebas del módulo de requisas

### Flutter

- `lib/domain/models/requisition_creation.dart`
- `lib/domain/models/requisition_detail.dart`
- `lib/domain/repositories/requisition_repository.dart`
- `lib/domain/repositories/requisition_detail_repository.dart`
- `lib/domain/repositories/acquisition_repository.dart`
- `lib/data/models/requisition_creation_dto.dart`
- `lib/data/services/requisition_creation_service.dart`
- `lib/data/services/requisition_service.dart`
- `lib/data/services/requisition_detail_service.dart`
- `lib/data/services/local_evidence_database_service.dart`
- `lib/data/services/evidence_sync_service.dart`
- `lib/data/repositories/remote_requisition_detail_repository.dart`
- `lib/data/repositories/acquisition_repository_impl.dart`
- `lib/ui/features/requisitions/detail/view_models/requisition_detail_view_model.dart`
- `lib/ui/features/requisitions/detail/views/requisition_detail_view.dart`
- `lib/ui/features/acquisition/mirror/view_models/mirror_view_model.dart`
- `lib/ui/features/acquisition/mirror/views/mirror_view.dart`
- nuevos widgets compartidos bajo `lib/ui/features/evidence/widgets/`
- `lib/core/di/dependency_injection.dart` solo si aparecen dependencias nuevas

## 9. Orden de implementación

### Fase 1 — contrato externo e identidad

- capturar fixtures anonimizados de casos y sujetos;
- tipar el gateway;
- documentar explícitamente que `segipPersonaId` y `suprPersona.id` comparten el mismo `personaId`, usado tanto para validar como para anclar evidencias;
- documentar que `suprCasosPersonas.id` es solo metadata de participación procesal y nunca un ID de anclaje;
- definir normalización de CI/complemento;
- implementar resolución exacta de caso;
- implementar la validación persona-CUD.

Salida: el backend puede decidir de forma confiable si una persona pertenece al CUD.

### Fase 2 — migración y persistencia backend

- crear `RequisitionCaseSubject` y `EvidenceSubjectLink`;
- agregar `Evidence.displayName`;
- reconciliar sujetos al crear/vincular casos;
- anclar automáticamente evidencias de requisas `PERSON`;
- ampliar proyecciones de detalle y galería.

Salida: sujetos y vínculos quedan persistidos con IDs estables e historial.

### Fase 3 — endpoints de evidencia

- implementar DTOs, servicio, puerto y repositorio para nombre y sujetos;
- agregar permisos, idempotencia, eventos de custodia y Swagger;
- actualizar sellado/manifiesto.

Salida: API completa y autorizada para las dos mutaciones.

### Fase 4 — modelos, cache y outbox Flutter

- introducir sujetos tipados y nombre visible;
- migrar SQLite;
- ampliar servicios/repositorios;
- soportar evidencia pendiente y reconciliación remota;
- registrar dependencias si corresponde.

Salida: la app conserva los cambios aun cuando la evidencia todavía no terminó de subir.

### Fase 5 — detalle de requisa

- actualizar validación y mensajes del vínculo con CUD;
- mostrar la lista completa y tipada de `suprCasosPersonas` en el detalle;
- agregar opciones al menú;
- implementar modal multiselección y modal de renombre;
- mostrar sujetos debajo de peso/estado.

Salida: flujo completo desde el detalle en todos los tamaños.

### Fase 6 — mirror

- agregar icono de edición junto al nombre;
- reutilizar el modal y comando de renombre;
- mantener sincronizado el panel de evidencias recientes.

Salida: una captura o grabación recién creada puede renombrarse desde el mirror.

### Fase 7 — migración histórica, documentación y validación

- ejecutar backfill/rehidratación controlada;
- actualizar diagramas y contratos;
- validar compatibilidad entre versiones de app y backend;
- desplegar backend antes o junto con la app que consume los campos nuevos.

## 10. Matriz de estados y permisos

| Operación | DRAFT | IN_PROGRESS | FINALIZING | SEALED | CANCELLED |
|---|---:|---:|---:|---:|---:|
| Vincular CUD | Sí | Sí | No | No | No |
| Renombrar evidencia | Sí | Sí | No | No | No |
| Cambiar sujetos | Sí | Sí | No | No | No |
| Consultar nombre/sujetos | Sí | Sí | Sí | Sí | Sí |

Para mutaciones se requiere permiso institucional y rol local `OWNER` o `EDITOR`. `VIEWER` solo consulta.

## 11. Casos de aceptación

### Vínculo con CUD

1. Requisa con `segipPersonaId = 1339` y caso con `suprPersona.id = 1339`: el CUD se vincula aunque `suprCasosPersonas.id` sea otro valor, por ejemplo `2626`, y las evidencias permanecen ancladas a `personId = 1339`.
2. Persona ausente del CUD: HTTP 409/422 funcional, no se crea ningún vínculo parcial y el modal muestra el error.
3. Caso con homónimo pero CI diferente: se rechaza.
4. Caso sin identificador confiable para confirmar a la persona: se rechaza, sin usar el nombre como fallback.
5. Requisa creada directamente desde CUD: todos los elementos de `suprCasosPersonas` quedan persistidos; los que tienen `suprPersona.id` quedan disponibles para seleccionar por su `personId`.

### Sujetos de evidencia

1. Evidencia de requisa `CASE` puede permanecer sin sujetos.
2. Se pueden seleccionar los `personIds` provenientes de `suprPersona.id`, por ejemplo `1339` y `1637`; ambas personas aparecen en el card y en la respuesta API.
3. Reemplazar Juan/Pedro por Ana conserva el historial y deja solo Ana activa.
4. Enviar un sujeto de otra requisa o de un CUD anterior se rechaza atómicamente.
5. Evidencia de requisa `PERSON` recibe automáticamente al sujeto principal.
6. Tras vincular esa requisa a un CUD, la persona principal sigue anclada y se pueden agregar otros sujetos.
7. Requisa sellada permite consultar, pero no editar vínculos.
8. Enviar `personId = 1339` es válido; enviar por error `suprCasosPersonas.id = 2626` dentro de `personIds` se rechaza.

### Detalle de sujetos procesales

1. El detalle lista los dos elementos completos del ejemplo, conservando tanto los IDs de participación `2626` y `2627` como sus `suprPersona.id` cuando existan.
2. Cada elemento muestra persona, CI, alias y tipo `Denunciante y Víctima` o `Denunciado` según corresponda.
3. Se conservan color, nivel, reserva de identidad, situación jurídica, estado actual y entidad jurídica aunque alguno sea nulo.
4. Una entidad jurídica sin `suprPersona` sigue siendo visible en la lista completa, pero no es seleccionable para anclaje mientras no exista un contrato específico para entidades.
5. La UI usa `suprPersona.id` como valor de selección y nunca lo confunde con `suprCasosPersonas.id`.

### Renombre

1. Renombrar desde el detalle actualiza ambos lugares de la app.
2. Renombrar desde mirror actualiza el card sin afectar captura/grabación.
3. Una evidencia local pendiente conserva el nombre tras reiniciar la app y lo sincroniza posteriormente.
4. El hash, tamaño, nombre original y objeto remoto permanecen iguales.
5. Nombre vacío, demasiado largo o con caracteres de control se rechaza.
6. Repetir la misma petición/idempotency key no duplica eventos.

### Responsive y accesibilidad

1. Modal usable en anchos compact, medium, expanded y large.
2. Sin overflow con texto grande y altura menor a 480.
3. Checkboxes, iconos y CTAs tienen al menos 48 dp y tooltips/semántica.
4. Teclado, mouse y teclado físico pueden recorrer y confirmar formularios.

## 12. Validación prevista

### Backend

- unitarias del normalizador de sujetos y de la regla persona-CUD;
- unitarias de renombre, reemplazo de sujetos e invariantes de requisa `PERSON`;
- repositorio Prisma con rollback ante IDs inválidos;
- E2E de los tres endpoints y permisos;
- migración desde una base con datos históricos y desde una base vacía;
- `format:check`, lint, typecheck, tests y build según `AGENTS.md` del backend.

### Flutter

- pruebas de parseo de sujetos y evidencias;
- repositorio/local DB para renombre y selección pendiente;
- ViewModels para doble submit, errores y reconciliación;
- widgets del modal y cards en viewports definidos;
- validación manual del propietario en detalle y mirror.

Por las reglas del repositorio Flutter, durante la futura implementación no se ejecutarán `flutter test`, `flutter analyze`, `flutter run`, `flutter build`, compilaciones nativas ni generadores salvo autorización expresa del propietario. El propietario deberá ejecutar esas validaciones y `build_runner` cuando se introduzcan modelos Freezed.

## 13. Riesgos y deuda a controlar

- El ejemplo real ya confirma la estructura principal de `suprCasosPersonas`; todavía se necesitan fixtures anonimizados con `suprEntidadJuridica`, `actualEstadoSujeto` y `situacionJuridicaId` no nulos para cerrar esos subcontratos.
- Los snapshots históricos con solo nombres no permiten un backfill seguro sin volver a consultar la fuente.
- La normalización del CI y su complemento debe acordarse con la regla del sistema de personas/casos; una normalización incorrecta puede producir falsos rechazos.
- Cambiar el CUD actual no debe borrar sujetos ni relaciones históricas.
- La outbox de metadata debe ordenar correctamente `CREATE_EVIDENCE_INTENT`, renombre y sujetos para que una operación no llegue antes de que exista la evidencia remota.
- La compatibilidad de despliegue requiere que el backend acepte temporalmente clientes antiguos y que los nuevos campos de respuesta sean aditivos.
- Los permisos nuevos deben existir en `ms-auth` antes de activar la UI en producción.

## 14. Fuera de alcance

- reconocimiento facial o sugerencias automáticas de sujetos según el contenido;
- modificación, recorte o reemplazo del archivo probatorio;
- renombrado físico del objeto en `ms-files-v2` o del contenedor FCE;
- rediseño general del detalle o del mirror;
- cambios al protocolo USB/ADB/scrcpy;
- nuevas rutas de navegación o deep links.

## 15. Resultado esperado de la futura implementación

Al finalizar, el sistema impedirá asociar una requisa personal a un CUD ajeno a esa persona, conservará sujetos procesales con identidad utilizable, permitirá describir a quién corresponde cada evidencia y ofrecerá un nombre visible editable desde detalle y mirror sin comprometer la integridad del archivo original ni su cadena de custodia.
