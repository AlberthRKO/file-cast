# Plan de migración a clave de cifrado por requisa

## Objetivo

Eliminar del camino crítico de cada subida la generación de una envoltura X25519 por dispositivo autorizado. Cada evidencia conserva una DEK independiente y el archivo FCE actual; la DEK se envuelve una sola vez con una clave simétrica versionada de la requisa (`RK`). La RK se distribuye a dispositivos y recuperación institucional únicamente al crearla, registrar un dispositivo nuevo o rotarla.

La base de desarrollo puede reiniciarse. Por eso el contrato nuevo será la fuente de verdad para evidencias nuevas y no se implementará una conversión automática de las envolturas históricas por archivo. La migración SQL sigue siendo aplicable sobre una base existente, pero este despliegue debe activarse después de eliminar las evidencias antiguas o reiniciar la base de desarrollo.

## Comparación

```text
Actual
  evidencia × dispositivos -> X25519/HKDF/AES-GCM -> intención -> upload

Nuevo
  alta/rotación de requisa -> RK × dispositivos (una sola vez, backend)
  cada evidencia           -> DEK × RK (AES-GCM local) -> intención -> upload
```

El backend ya dispone de recuperación institucional y, por diseño, puede reconstruir una DEK. Generar la RK temporalmente en el backend no amplía ese nivel de confianza: la clave se crea con CSPRNG, se envuelve para recuperación y dispositivos, y el material plano no se persiste ni se registra.

## Modelo de datos backend

### `RequisitionEncryptionKey`

- `id`: UUID de la RK.
- `requisitionId`: requisa propietaria.
- `version`: versión monotónica dentro de la requisa.
- `algorithm`: `AES-256-GCM`.
- `createdAt/createdBy`.
- `retiredAt/retiredBy`: rotación o revocación.
- unicidad `(requisitionId, version)` y una sola clave activa por requisa.

### `RequisitionKeyEnvelope`

- `requisitionKeyId`.
- `recipientType`: `DEVICE` o `RECOVERY`.
- `recipientId`: UUID del dispositivo o id de recuperación institucional.
- `wrapAlgorithm`: `X25519-HKDF-SHA256-AES-256-GCM`.
- `recipientKeyVersion`.
- `wrappedKey`.
- auditoría y revocación.

`FileKeyEnvelope` permanece, pero las evidencias nuevas guardan exactamente una fila con `recipientType = REQUISITION_KEY`, `recipientId = RequisitionEncryptionKey.id` y `wrapAlgorithm = AES-256-GCM-REQUISITION-KEY`.

## Contrato HTTP

### Registro del dispositivo

`POST /api/v1/requisitions/:id/encryption/devices`

- conserva idempotencia y propiedad del dispositivo;
- asegura que exista una RK activa;
- provisiona la envoltura de esa RK para el dispositivo;
- deja de recorrer todas las evidencias históricas.

### Obtener RK del dispositivo

`GET /api/v1/requisitions/:id/encryption/requisition-key?deviceId=...`

Respuesta:

```json
{
  "requisitionKeyId": "uuid-rk",
  "requisitionKeyVersion": 1,
  "requisitionKeyAlgorithm": "AES-256-GCM",
  "recipientType": "DEVICE",
  "recipientId": "uuid-device",
  "wrapAlgorithm": "X25519-HKDF-SHA256-AES-256-GCM",
  "keyVersion": 1,
  "wrappedKey": "..."
}
```

Si falta la envoltura del dispositivo, el backend abre la envoltura institucional de la RK, genera solo la del dispositivo solicitado y vuelve a descartar la clave plana.

### Crear intención de evidencia

`POST /api/v1/requisitions/:id/evidence-intents`

Las evidencias cifradas envían una sola `keyEnvelope`:

```json
{
  "recipientType": "REQUISITION_KEY",
  "recipientId": "uuid-rk",
  "wrapAlgorithm": "AES-256-GCM-REQUISITION-KEY",
  "keyVersion": 1,
  "wrappedKey": "..."
}
```

El backend valida que la RK sea activa, pertenezca a la requisa y coincida con la versión declarada.

### Recuperación offline

`GET /api/v1/requisitions/:id/evidences/:evidenceId/key-envelope?deviceId=...`

- valida que el dispositivo pertenezca al actor;
- devuelve la envoltura `REQUISITION_KEY` de la DEK;
- la app abre primero su RK y después la DEK;
- ya no se crea una envoltura X25519 por evidencia y dispositivo.

## Cambios en la app

1. `EvidenceKeyExchangeService` registra el dispositivo y obtiene la RK activa.
2. `EvidenceCryptoService` abre la RK una vez con X25519 y la guarda:
   - en memoria para la sesión;
   - en `flutter_secure_storage` usando requisa, id y versión como identidad.
3. Al subir una evidencia:
   - abre la DEK desde la bóveda local;
   - envuelve la DEK con RK mediante AES-256-GCM;
   - envía una sola `keyEnvelope`;
   - no consulta `encryption/recipients` ni genera envolturas por participante.
4. Al recuperar una evidencia:
   - obtiene la RK del dispositivo una sola vez;
   - obtiene la envoltura DEK→RK de la evidencia;
   - reenvuelve la DEK para la bóveda local y valida el FCE como hoy.
5. La carga del detalle prepara la RK en segundo plano para que importar, capturar o grabar no pague ese costo al presionar **Cargar**.

## Participantes y detalle

- `RequisitionAccess` guardará `actorName` y `actorDocument` como snapshot de auditoría; el API los expondrá como `fullName` y `documentNumber`.
- El propietario se toma del usuario autenticado al crear la requisa.
- Los invitados se toman de la respuesta de ms-auth al conceder acceso.
- `GET /requisitions/:id` devolverá esos campos sin consultar ms-auth por cada lectura.
- Se elimina `evidences[].urls`; las rutas REST son determinísticas y la app construye internamente la ruta de contenido cuando necesita recuperación offline.

## Rotación y revocación

- La versión inicial es `1`.
- Al revocar un dispositivo o participante se debe retirar la RK activa y crear la siguiente versión para evidencias futuras.
- Las evidencias existentes conservan la versión con la que fueron creadas.
- Una eliminación de acceso no puede retirar material que un dispositivo ya descargó; la rotación protege contenido futuro.
- La UI de administración y el endpoint explícito de rotación quedan como fase posterior; el esquema ya admite múltiples versiones.

## Orden de implementación

1. Migración Prisma y modelos de RK/envolturas; snapshots de participantes.
2. Servicio de recuperación genérico por contexto criptográfico.
3. Repositorio backend: alta/obtención/provisión de RK y validación de intención.
4. Controller/DTO/Swagger y retiro de `urls`.
5. App: contrato de RK, caché segura y envoltura simétrica de DEK.
6. App: subida y recuperación offline con el contrato nuevo.
7. Preparación anticipada de RK al abrir el detalle.
8. Documentación y revisión estática de ambos repositorios.

## Validación funcional esperada

- primera apertura de una requisa nueva: registra dispositivo y prepara una RK;
- primera captura: no consulta destinatarios y envía una envoltura;
- diez capturas: diez envolturas AES locales, no `10 × dispositivos`;
- nuevo dispositivo: una envoltura de RK y acceso a todas las evidencias de esa versión;
- recuperación offline: hash ciphertext, autenticación FCE y hash plano se mantienen;
- detalle: participantes con nombre y evidencias sin `urls`;
- reinicio de app: RK recuperada desde almacenamiento seguro sin repetir X25519.

## Reinicio del entorno dev

Aplicar la migración versionada y reiniciar la base únicamente mediante el procedimiento local del propietario. No usar `prisma db push` para despliegue. Después de limpiar también conviene borrar datos de la app o reinstalarla para eliminar la outbox y las claves locales del flujo anterior.
