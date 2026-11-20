# Plan: cambio de rol de participantes

**Estado:** implementado en el código de `file-cast-back` y Flutter, 20 de
noviembre de 2026. La validación automática queda pendiente.

## Objetivo

Permitir que el propietario cambie entre **Editor** y **Lector** desde la hoja
de participantes del detalle de una requisa. La autorización y la jerarquía se
validarán siempre en `file-cast-back`; ocultar o deshabilitar controles en
Flutter solo mejora la interfaz y no sustituye esa validación.

El plan conserva las decisiones de contrato, jerarquía, auditoría y UX usadas
por la implementación de backend y frontend.

## Revisión de documentación y código actual

### Flutter

- `docs/modules/requisitions_detail.md` documenta que la lista se forma con los
  accesos activos del backend (`actorId` y `role`) y que la hoja inferior es
  parte del detalle responsive.
- `RequisitionDetailView` convierte esos participantes a un modelo visual que
  no conserva `actorId`; `_PeopleSheet` solo muestra datos y etiqueta de rol.
  La hoja se abre actualmente cuando hay más de un participante.
- El formulario de alta es otra hoja (`_ParticipantSheet`). El `ViewModel` ya
  restringe la gestión de participantes al propietario en requisas `DRAFT` o
  `IN_PROGRESS`; el servicio existente hace `POST /accesses`.
- El dominio ya tiene `RequisitionParticipantSummary` y los roles de alta
  `EDITOR`/`VIEWER`, por lo que no hace falta inventar roles nuevos.

### Backend

- `docs/requisitions/README.md` establece que solo el dueño administra accesos.
  `RequisitionsService` y `PrismaRequisitionsRepository.grantAccess` aplican
  actualmente esa regla exigiendo `OWNER`.
- `AccessRole` define `OWNER`, `EDITOR` y `VIEWER`; el detalle devuelve los
  accesos activos, no el historial.
- `RequisitionAccess` ya conserva vigencia con `validFrom`/`validTo` y la base
  impide dos accesos activos para la misma persona en una requisa. El ledger
  append-only ya permite auditar cambios, aunque su enum todavía no contempla
  cambios de rol.
- No se encontró una matriz de jerarquía independiente. Este plan formaliza la
  regla existente de que solo `OWNER` administra accesos.

## Política de roles

La jerarquía conceptual es `OWNER > EDITOR > VIEWER`, con estas reglas:

| Actor autenticado | Objetivo | Cambio permitido |
|---|---|---|
| `OWNER` | Participante activo con `EDITOR` o `VIEWER` | Cambiar entre `EDITOR` y `VIEWER` |
| `OWNER` | Su propio acceso o cualquier acceso `OWNER` | No permitido |
| `EDITOR` | Cualquier participante | No permitido |
| `VIEWER` | Cualquier participante, incluso sí mismo | No permitido |

- El endpoint solo acepta `EDITOR` o `VIEWER`; el cliente no puede asignar ni
  modificar `OWNER`.
- El actor se obtiene de `CurrentActor` y del acceso vigente en base de datos.
  No se acepta un actor, rol del operador ni nivel de autorización enviado en
  el body.
- El objetivo debe ser otra persona con acceso activo en esa misma requisa.
  El propietario no puede cambiar su propio rol ni transferir propiedad por
  este flujo.
- La operación solo procede en `DRAFT` o `IN_PROGRESS`; `SEALED` y `CANCELLED`
  quedan bloqueadas.
- Solicitar el rol que ya tiene el participante debe ser un no-op exitoso, sin
  crear una fila histórica nueva ni un evento duplicado.
- El cambio es online y autoritativo del servidor. No se guarda en la outbox
  offline de evidencias.

## Contrato propuesto para `file-cast-back`

```http
PATCH /api/v1/requisitions/:id/accesses/:actorId
Content-Type: application/json
Idempotency-Key: <clave única por operación>

{ "role": "EDITOR" }
```

`:actorId` es el identificador institucional ya incluido en cada participante
del detalle; es una cadena, no necesariamente un UUID. El body se valida con un
DTO que permite exclusivamente `EDITOR` o `VIEWER`.

La respuesta `200` usa el sobre HTTP vigente y devuelve el acceso actualizado
en `response.data` (`actorId`, `role` y vigencia). Se mantiene la respuesta
normalizada de errores del backend: `403` para actor sin autoridad, `404` para
objetivo sin acceso activo y `409` para requisa no editable o conflicto de
concurrencia. La idempotencia protege reintentos del cliente.

### Trabajo del backend

1. Añadir el DTO de cambio de rol y el método correspondiente al puerto de
   `RequisitionsRepository`.
2. Añadir `changeAccessRole` al servicio y `PATCH` al
   `RequisitionsController`. Aplicar `@RequirePermissions` con el permiso
   existente `requisitions.access-grant` a `POST /accesses` y al nuevo `PATCH`,
   junto con `@Idempotent()` en las mutaciones; verificar el registro y la
   asignación del permiso en `ms-auth`. Mantener además la autorización por
   requisa: el servicio y el repositorio deben exigir que el actor actual sea
   `OWNER`.
3. En el repositorio Prisma, ejecutar una transacción corta que:
   - compruebe existencia y estado editable de la requisa;
   - obtenga el acceso activo del objetivo y rechace `OWNER`/actor propio;
   - cierre el acceso vigente (`validTo`) y cree otro acceso vigente con el rol
     solicitado, conservando `actorName` y `actorDocument`;
   - compruebe que la fila se cerró bajo la condición de rol/vigencia esperada;
     ante un cambio concurrente, responder `409` sin sobrescribir el resultado
     más reciente;
   - incremente `Requisition.version` y actualice `updatedBy`;
   - agregue al ledger `PARTICIPANT_ROLE_CHANGED`, con actor, objetivo, rol
     anterior y rol nuevo.
4. Añadir una migración Prisma versionada para el nuevo valor del enum del
   ledger, mapeado a `ROL_PARTICIPANTE_CAMBIADO`. No modificar migraciones ya
   aplicadas ni `src/generated` manualmente.
5. Mantener la participación y la elegibilidad criptográfica del usuario: un
   cambio entre editor y lector no revoca su acceso ni requiere rotar la clave
   de la requisa. La revocación total de accesos queda fuera de este alcance.
6. Actualizar `docs/requisitions/README.md` y el plan/contrato del módulo para
   describir la matriz, el nuevo endpoint, el permiso y la auditoría.

## Trabajo del frontend Flutter

La ruta del detalle no cambia. Se mantiene el flujo:

```text
modal de participantes → ViewModel → RequisitionRepository
  → RemoteRequisitionRepository → RequisitionService → PATCH del backend
```

1. Añadir `changeParticipantRole(requisitionId, actorId, role)` al contrato del
   repositorio y conectarlo a la implementación remota y al servicio HTTP. El
   servicio envía la clave de idempotencia y el enum existente serializado como
   `EDITOR`/`VIEWER`.
2. Añadir un comando al `RequisitionDetailViewModel`. Debe comprobar
   `canManageParticipants`, impedir doble envío, exponer progreso/error por
   participante y recargar el detalle remoto al confirmar, dejando al backend
   como fuente de verdad. Si falla, conservar el rol anterior y presentar el
   error; en conflicto, recargar para mostrar el rol vigente.
3. Cambiar la hoja actual para recibir `RequisitionParticipantSummary` y
   callbacks explícitos en lugar de una lista visual que pierde `actorId`.
   Extraerla a `lib/ui/features/requisitions/detail/widgets/` si así se mantiene
   pequeña la View contenedora.
4. Mostrar selector de rol solo al propietario y solo en filas no propietarias.
   La fila `Propietario` queda protegida. Para otros usuarios, mostrar el rol
   actual y las opciones **Editor**/**Lector**. Deshabilitar el selector durante
   la petición y para el rol ya seleccionado.
5. Permitir abrir la hoja desde el resumen de participantes cuando hay filas
   que gestionar, incluso si el layout actual no ofrece una acción accesible
   por tener un único elemento visible.
6. Conservar idioma, tema y lenguaje visual existente. Usar constraints locales,
   `SafeArea`, scroll para listas largas, targets de al menos 48 dp y un ancho
   máximo legible en pantallas grandes. El selector debe seguir siendo usable
   con texto ampliado, teclado, mouse y ventanas compactas; no escoger el layout
   por orientación o tipo de dispositivo.
7. Mantener los participantes visibles en modo lectura para los demás roles.
   Si no hay conexión, no ofrecer cambios pendientes locales; presentar el
   error de red y conservar el rol remoto conocido.
8. Actualizar `docs/modules/requisitions_detail.md` con el nuevo flujo, estados,
   permisos y comportamiento responsive.

No se requiere un Use Case nuevo: es una operación CRUD simple del mismo
repositorio y no coordina varios repositorios.

## Secuencia de entrega

1. **Backend:** contrato, permiso, DTO, servicio/puerto, transacción Prisma,
   auditoría y migración.
2. **Frontend:** servicio/repositorio, comando del ViewModel, selector en la hoja
   y estados de error/carga.
3. **Documentación y validación:** actualizar documentación en ambos repos,
   cubrir reglas y concurrencia con las pruebas del proyecto y revisar el flujo
   de extremo a extremo con las cuentas `OWNER`, `EDITOR` y `VIEWER`.

## Criterios de aceptación

- El propietario puede cambiar un editor a lector y un lector a editor desde la
  hoja; el rol confirmado aparece tras recargar el detalle.
- Lector y editor reciben `403` si intentan llamar directamente al endpoint.
- No se puede convertir un acceso en `OWNER`, cambiar el rol del propietario ni
  elevar el propio rol.
- Una requisa sellada/cancelada no admite cambios.
- Dos cambios concurrentes no pisan silenciosamente la decisión más reciente;
  el historial conserva el acceso anterior y el evento registra ambos roles.
- Un fallo de red o permiso no deja el selector mostrando un cambio no
  confirmado ni crea una mutación offline.
- El modal funciona en anchos compactos y expandidos, con lista desplazable,
  texto ampliado y controles accesibles.

La validación pendiente debe cubrir servicio/repositorio y ViewModel, además del
contrato de permisos, concurrencia, reintentos y restricciones jerárquicas. No
se agregaron ni ejecutaron pruebas en esta entrega.

## Implementación realizada y validación

- Backend: `PATCH /api/v1/requisitions/:id/accesses/:actorId`, permiso
  `requisitions.access-grant`, validación duplicada de `OWNER`, transacción que
  conserva la vigencia histórica y evento de ledger
  `ROL_PARTICIPANTE_CAMBIADO`.
- Flutter: servicio/repositorio remoto, comando MVVM y selector Editor/Lector
  dentro de la hoja responsive; la confirmación actualiza el snapshot y vuelve
  a consultar el detalle remoto.
- Migración versionada y documentos del detalle/base de datos actualizados.
- El propietario aplicó la migración correctamente a la base de desarrollo y
  `prisma migrate status` confirmó que el esquema está actualizado.
- Se reutiliza `requisitions.access-grant`; la definición/carga de permisos en
  `ms-auth` no está en ninguno de los dos repositorios revisados y queda por
  confirmar en el ambiente integrado.
- Se ejecutaron `dart format`, `corepack yarn prisma:generate` y
  `corepack yarn prisma format`. No se ejecutaron tests, analyze, build ni run;
  el código no fue compilado ni validado automáticamente.
- El worktree Flutter ya tenía un cambio local en
  `lib/ui/features/acquisition/mirror/views/mirror_view.dart`; se conservó sin
  tocarlo.
