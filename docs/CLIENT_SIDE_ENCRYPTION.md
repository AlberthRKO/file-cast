# Cifrado local y modo offline

## Flujo implementado

La aplicación no guarda evidencias registradas en plano. Las capturas de
pantalla, grabaciones, transferencias ADB y archivos seleccionados pasan por el
siguiente flujo:

```text
archivo temporal de adquisición
        ↓
AES-256-GCM por bloques de 1 MiB
        ↓
archivo opaco <nombre-original>.fce
        ↓
SQLite SQLCipher + outbox
        ↓  conectividad o reintento
file-cast-back → ms-files-v2
```

El archivo plano se elimina después de crear correctamente el contenedor FCE.
Los archivos temporales de vista previa se descifran solo durante la vista y se
eliminan cuando el widget se desmonta.

## Formato FCE

- Magic: `FCE` versión 1.
- Bloques de hasta 1 MiB.
- Cada bloque tiene longitud original, nonce de 12 bytes, ciphertext y tag GCM
  de 16 bytes.
- La AAD incluye el UUID de la evidencia y el índice de bloque.
- Se calcula SHA-256 del plano y del FCE completo.

Cada evidencia usa una DEK aleatoria. La DEK se envuelve localmente con una
clave de bóveda de 256 bits almacenada en `flutter_secure_storage`. Para permitir
el acceso de participantes, el dispositivo también genera un par X25519: solo
la clave pública se registra en el backend y la privada permanece en el almacén
seguro. La DEK se envuelve una vez por cada dispositivo autorizado usando
X25519 + HKDF-SHA256 + AES-256-GCM. La base SQLCipher tiene otra clave aleatoria
almacenada en el mismo almacén seguro.

En Android, el build release conserva las clases nativas de SQLCipher mediante
`android/app/proguard-rules.pro`. Antes de distribuir una versión release se
debe ejecutar el build con Flutter 3.35 o superior y comprobar la apertura de
la base en un dispositivo real.

## Persistencia local

La base `file_cast_evidence_v1.db` contiene:

- `evidencias_locales`: ruta FCE, hashes, tamaños, metadata y `wrappedKey`.
- `outbox_evidencias`: estado de sincronización, intentos y último error.

No se guardan bytes del contenido plano en SQLite. La outbox usa los estados
`PENDIENTE`, `ERROR` y `SINCRONIZADA`. `connectivity_plus` dispara nuevos intentos
cuando vuelve la conectividad, y una captura nueva también intenta consumir la
outbox.

## Contrato con el backend

La app crea primero `POST /api/v1/requisitions/{id}/evidence-intents` con:

- `byteLength` y `sha256` del FCE;
- `plaintextByteLength` y `plaintextSha256`;
- `encryptionAlgorithm`, `encryptionVersion` y `aadHash`;
- `keyEnvelopes` dirigidas a los dispositivos activos de los actores con acceso;
- tipo y método de adquisición.

Después envía el mismo `evidenceId` en
`POST /api/v1/requisitions/{id}/evidences/upload`. El archivo multipart usa
nombre `.fce` y MIME `application/vnd.file-cast.encrypted`.

La sincronización solo marca la fila como completada al recibir el `msFileId`.
Una falla conserva el archivo y permite reintentar sin crear una nueva
evidencia.

## Recuperación

Al registrar una requisa, cada dispositivo autorizado publica su clave X25519.
El dueño/editor obtiene las claves públicas activas y envía al backend una
envoltura de la misma DEK por dispositivo. Un participante obtiene únicamente
su envoltura mediante `GET .../key-envelope`, solicita el contenido mediante la
ruta autenticada de `file-cast-back` y descifra localmente. `file-cast-back`
genera internamente la URL firmada y envía el `x-session-token` a `ms-files-v2`;
el token y la URL firmada ya no llegan al móvil. `ms-files-v2` nunca recibe la
DEK ni el contenido plano. En el modo de recuperación institucional,
`file-cast-back`/KMS abre temporalmente la envoltura de recuperación únicamente
para volver a envolver la DEK con la clave pública del nuevo dispositivo; la
DEK no se persiste en claro.

La vista previa escribe cada descarga en un temporal único, verifica que el
archivo recibido tenga el tamaño FCE esperado y lee el contenedor por completo
aunque el sistema entregue lecturas parciales. El hash del contenido plano
continúa siendo la validación final; esto permite abrir evidencias antiguas con
metadatos de tamaño plano desactualizados sin aceptar contenido alterado.

Si el dueño agrega un dispositivo después de haber subido evidencias, el
backend provisiona las envolturas desde la copia institucional y la app del
dueño también puede reparar evidencias antiguas mientras conserve la bóveda
local. Por eso la pérdida, robo, cambio o desinstalación del teléfono no
elimina el acceso: al registrar el nuevo dispositivo se reenvuelven todas las
DEK disponibles. Mientras no exista una copia local, el preview descarga el
FCE remoto y lo descifra localmente; la acción de sincronización offline puede
preparar después todas las copias persistentes de la requisa.

La recuperación requiere configurar `ENV_ENCRYPTION_RECOVERY_PRIVATE_KEY` en
un secreto/KMS del backend. Sin esa copia institucional, una evidencia creada
antes de la recuperación o con el secreto deshabilitado solo puede recuperarse
desde un dispositivo autorizado que conserve su clave privada.

Una evidencia antigua no se puede reconstruir después de desinstalar el único
dispositivo que conservaba la bóveda local si nunca llegó a existir su
envoltura `RECOVERY`. En ese caso el backend seguirá mostrando el archivo FCE,
pero `GET .../key-envelope` responderá sin datos: ms-files-v2 conserva el
ciphertext, no la DEK. La reparación de evidencias antiguas solo es posible
antes de perder ese dispositivo, abriendo la requisa con la app actual para
que el dueño/editor publique la envoltura institucional.

Durante una sincronización, el detalle de la requisa puede mostrar el error
local de preparación de la envoltura y el botón de reintento conserva la misma
operación idempotente. Si la outbox ya estaba ejecutándose al confirmar una
nueva selección, se agenda automáticamente otro ciclo al terminar el actual.
Las envolturas X25519 llevan una clave de idempotencia derivada de su contenido:
una repetición exacta se reproduce y una nueva envoltura aleatoria puede
actualizar de forma segura el registro sin provocar un conflicto artificial.

## Preparar evidencias para uso offline

El detalle de la requisa incluye la acción **Sincronizar para uso offline**.
Está dirigida a cada dispositivo participante y no es una nueva subida. Para
cada evidencia FCE que ya esté `AVAILABLE`, la acción:

1. obtiene del backend la envoltura de la DEK correspondiente al dispositivo;
2. descarga una sola vez el FCE mediante
   `GET /api/v1/requisitions/{id}/evidences/{evidenceId}/content`;
3. valida tamaño y SHA-256 del ciphertext;
4. vuelve a envolver la DEK con la bóveda local del dispositivo;
5. valida el FCE completo y el hash/tamaño del contenido plano, sin conservar
   el plano como caché permanente;
6. mueve el archivo a `evidence_files/{evidenceId}.fce` y registra sus metadatos
   en `evidencias_locales` con estado `SINCRONIZADA`.

Las evidencias que ya tienen una copia FCE íntegra se omiten. La operación
elimina cualquier registro de outbox de esa evidencia porque la subida ya
terminó en el servidor: los archivos recuperados no vuelven a `PENDIENTE` ni
se duplican en la cola de subida. Después de esta preparación, las miniaturas
y previews usan la ruta local y solo una nueva reinstalación o limpieza del
almacenamiento vuelve a requerir el puente remoto.

El progreso es por requisa y se muestra como archivos guardados localmente,
omitidos o con error. Si falla una evidencia, las demás pueden continuar y el
botón permite reintentar únicamente las copias que todavía no sean utilizables.
Cada participante debe ejecutar la acción en su propio dispositivo; el backend
provee las claves y el ciphertext, pero no puede escribir archivos dentro del
almacenamiento privado de otro teléfono.

## Prueba local

La prueba `test/data/services/evidence_crypto_service_test.dart` cubre un
archivo mayor a un bloque, eliminación del plano, descifrado y verificación de
hash/tamaño. Por las restricciones del proyecto, la validación de Flutter se
ejecuta en CI o en un entorno con la versión fijada en `.fvmrc`/SDK; no se deben
usar generadores para este flujo.
