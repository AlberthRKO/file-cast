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

Cada evidencia usa una DEK aleatoria. La DEK se envuelve con una clave de bóveda
de 256 bits almacenada en `flutter_secure_storage`. La base SQLCipher tiene otra
clave aleatoria almacenada en el mismo almacén seguro.

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
- `keyEnvelope` dirigida al dispositivo;
- tipo y método de adquisición.

Después envía el mismo `evidenceId` en
`POST /api/v1/requisitions/{id}/evidences/upload`. El archivo multipart usa
nombre `.fce` y MIME `application/vnd.file-cast.encrypted`.

La sincronización solo marca la fila como completada al recibir el `msFileId`.
Una falla conserva el archivo y permite reintentar sin crear una nueva
evidencia.

## Recuperación

La versión actual permite leer la evidencia en el dispositivo que conserva su
clave de bóveda. Para recuperación institucional o cambio de dispositivo se
debe agregar una segunda envoltura de la DEK con una clave pública institucional
o KMS/Vault. No se debe sincronizar la clave privada del dispositivo.

## Prueba local

La prueba `test/data/services/evidence_crypto_service_test.dart` cubre un
archivo mayor a un bloque, eliminación del plano, descifrado y verificación de
hash/tamaño. Por las restricciones del proyecto, la validación de Flutter se
ejecuta en CI o en un entorno con la versión fijada en `.fvmrc`/SDK; no se deben
usar generadores para este flujo.
