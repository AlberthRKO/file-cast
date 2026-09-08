# ADB Handshake - Documentacion Completa (Fase 1-5)

> **Documento histórico del prototipo.** Describe las fases 1 a 5. El código actual también contiene mirror/decoder y control táctil validado (fases 6–7), dimensiones dinámicas desde MediaCodec, captura PNG por `exec:screencap -p`, remultiplexado H.264 a MP4 y una primera vertical de transferencia ADB Sync (fase 8). Para el flujo vigente consultar [modules/acquisition_capture.md](modules/acquisition_capture.md), [modules/acquisition_transfer.md](modules/acquisition_transfer.md), [PROJECT_STATUS_AND_FEASIBILITY.md](PROJECT_STATUS_AND_FEASIBILITY.md) e [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).

## Fase 1: Deteccion USB y Permisos

### Objetivo
Detectar dispositivos Android conectados via USB OTG y solicitar permisos de acceso.

### Archivos clave
- `android/.../usb/UsbPlugin.kt` - Plugin principal + BroadcastReceiver
- `android/.../usb/UsbAdbTransport.kt` - Transferencia USB bulk + handshake
- `android/.../adb/AdbProtocol.kt` - Constantes y construccion de paquetes ADB
- `android/.../adb/AdbAuth.kt` - Keypair RSA + firma
- `lib/core/adb/adb_client.dart` - Cliente Dart (MethodChannel + EventChannel)
- `lib/core/adb/adb_models.dart` - Modelos UsbDeviceInfo, UsbEvent
- `lib/.../usb_device_list_page.dart` - UI lista de dispositivos

### Procedimiento
1. Manifest: permisos USB host + intent-filter + device_filter.xml
2. BroadcastReceiver: `ACTION_USB_PERMISSION`, `USB_DEVICE_ATTACHED`, `USB_DEVICE_DETACHED`
3. Deteccion: `UsbManager.deviceList` mapeado a `UsbDeviceInfo`
4. Permisos: `UsbManager.requestPermission()` con PendingIntent
5. EventChannel: eventos en tiempo real hacia Dart

---

## Fase 2: Handshake ADB con RSA Auth

### Flujo del protocolo
```
Host (app)                         Device (Samsung)
   |--- CNXN (version, "host::") --->|
   |<-- AUTH (TOKEN, 20 bytes) ------|
   |--- AUTH (SIGNATURE, firma) ---->|
   |<-- AUTH (TOKEN, 20 bytes) ------|  (rechazada)
   |--- AUTH (RSAPUBLICKEY, b64) --->|
   |         [Dialog Allow USB debug]|
   |<-- CNXN (conexion OK) ---------|
```

### Bugs corregidos

#### 1. Event type mismatch (ROOT CAUSE)
Kotlin envia `"adb_state"` (snake_case) pero Dart enum usa `adbState` (camelCase).
El fallback descartaba TODOS los eventos de estado ADB silenciosamente.

Fix: mapeo explicito en `UsbEvent.fromMap()`.

#### 2. Public key wire format
El payload de AUTH_RSAPUBLICKEY debe ser **base64-encoded** del `android_pubkey` struct.
El device hace `"PK" + key_data` y decodifica base64.

#### 3. android_pubkey struct (524 bytes, no 520)
```
modulus_size_words  [4 bytes] = 64 (little-endian)
n0inv              [4 bytes] Montgomery parameter
modulus            [256 bytes] little-endian
rr                 [256 bytes] Montgomery R^2 mod n, little-endian
exponent           [4 bytes] = 65537
```

#### 4. Modulus endianness
Java BigInteger toByteArray() es big-endian. El struct AOSP requiere little-endian.
Fix: `.reverse()` al modulus y rr despues de generar.

#### 5. RR computation
Incorrecto: `two.modPow(2^4096, n)` = 2^(2^4096) mod n
Correcto: `BigInteger.valueOf(2).modPow(4096, n)` = 2^4096 mod n

#### 6. Signing algorithm
AOSP usa `RSA_verify(NID_sha1, ...)` que hashea internamente.
Fix: usar `NONEwithRSA` en vez de `SHA1withRSA`.

#### 7. bulkTransfer hanging post-auth
Samsung reenumera USB despues de aceptar dialog, bulkTransfer cuelga.
Fix: watchdog thread que fuerza `connection.close()` despues de timeout.

#### 8. UI thread error
`result.success()`/`result.error()` se llamaba desde background thread.
Fix: envolver en `mainHandler.post { }`.

### Archivos modificados
- `AdbAuth.kt` - Struct 524 bytes, LE, fix RR, base64 encoding
- `UsbAdbTransport.kt` - Base64 payload, watchdog, logs completos
- `AdbProtocol.kt` - CNXN identity `"host::"`, maxPayload USB 16KB
- `UsbPlugin.kt` - mainHandler.post para results, re-attach logic
- `adb_models.dart` - Mapeo snake_case a camelCase
- `usb_device_list_page.dart` - Log panel siempre visible, retry/cancel buttons

---

## Fase 3: Stream Multiplexing

### Objetivo
Implementar el protocolo de multiplexacion de streams de ADB sobre una sola conexion USB. Permite abrir, leer, escribir y cerrar multiples streams simultaneamente (shell, sync, scrcpy).

### Protocolo ADB - Headers (24 bytes, little-endian)
```
[0..3]   command    (4 bytes)  - A_CNXN, A_OPEN, A_OKAY, A_WRTE, A_CLSE, A_AUTH
[4..7]   arg0       (4 bytes)  - Comando especifico (localId, remoteId, etc.)
[8..11]  arg1       (4 bytes)  - Comando especifico
[12..15] dataLength (4 bytes)  - Longitud del payload
[16..19] dataCheck  (4 bytes)  - CRC32 del payload
[20..23] magic      (4 bytes)  - command XOR 0xFFFFFFFF
```

### Constantes de comandos
| Comando | Valor | Descripcion |
|---------|-------|-------------|
| A_CNXN | 0x4e584e43 | Connect |
| A_OPEN | 0x4e45504f | Abrir stream |
| A_OKAY | 0x59414b4f | Acknowledge / Listo |
| A_WRTE | 0x45545257 | Escribir datos |
| A_CLSE | 0x45534c43 | Cerrar stream |
| A_AUTH | 0x48545541 | Autenticar |

### Flujo de multiplexacion
```
Host (app)                              Device
    |                                     |
    |-- OPEN(localId=1, "shell:id") ---->|
    |<-- OKAY(remoteId=5, localId=1) ----|  (device asigna remoteId)
    |-- WRTE(localId=1, remoteId=5, "")->|
    |<-- OKAY(remoteId=5, localId=1) ----|  (flow control)
    |<-- WRTE(remoteId=5, localId=1, data)|
    |-- OKAY(localId=1, remoteId=5) ---->|
    |<-- CLSE(remoteId=5, localId=1) ----|  (shell cierra al terminar)
    |-- CLSE(localId=1, remoteId=5) ---->|
```

### Implementacion en UsbAdbTransport.kt

#### Reader Thread (`startReaderThread`)
- Thread background que lee paquetes ADB en loop
- Demultiplexea: busca stream por `message.arg1` (host localId)
- **A_OKAY**: Registra `message.arg0` como remoteId en el stream
- **A_WRTE**: Encola payload en `stream.dataQueue`, envia A_OKAY de vuelta
- **A_CLSE**: Marca stream como cerrado, remueve del mapa

#### Flow Control (writeOkayQueue)
Cada `AdbStream` tiene una `writeOkayQueue: LinkedBlockingQueue<Int>`. El primer A_OKAY confirma exclusivamente `A_OPEN`; los siguientes se encolan para confirmar `A_WRTE`. `writeStream()` espera en esta cola con timeout, logrando control de flujo por-stream sin permitir que dos escrituras queden en vuelo.

#### Multiplexacion de streams
```kotlin
val streams: ConcurrentHashMap<Int, AdbStream>  // localId -> stream
val localIdCounter: AtomicInteger                // IDs monotonicos
val writeLock: ReentrantLock                      // Serializa USB writes
val readLock: ReentrantLock                       // Serializa USB reads
```

### Metodos principales
| Metodo | Descripcion |
|--------|-------------|
| `openStream(service, timeoutMs)` | Envia A_OPEN, espera A_OKAY, retorna AdbStream |
| `writeStream(localId, data, waitForOkay)` | Envia A_WRTE con flow control |
| `readStream(localId, timeoutMs)` | Lee de stream.dataQueue con timeout |
| `closeStream(localId)` | Envia A_CLSE, remueve del mapa |
| `isStreamOpen(localId)` | Verifica si el stream esta abierto |

### Bug critico: CNXN payload drain
Despues del handshake, el device puede enviar datos residuales en el stream de control. Si no se drenan antes de iniciar el reader thread, todos los paquetes subsiguientes se desincronizan.

Fix: Leer y descartar cualquier dato pendiente despues de recibir CNXN antes de llamar `startReaderThread()`.

---

## Fase 4: Push y Ejecucion de scrcpy-server

### Objetivo
Transferir el archivo `scrcpy-server-v2.7.jar` al device via ADB sync protocol, y ejecutarlo como proceso Java via `app_process`.

### Protocolo ADB Sync (push)

#### Constantes sync
| Constante | Valor | Descripcion |
|-----------|-------|-------------|
| SYNC_SEND | `"SEND"` | Comando de envio |
| SYNC_DATA | `"DATA"` | Bloque de datos |
| SYNC_DONE | `"DONE"` | Fin de transferencia |
| SYNC_OKAY | `"OKAY"` | Exito |
| SYNC_FAIL | `"FAIL"` | Error |
| REG_FILE | 33188 | Modo archivo (0o100644) |
| PUSH_CHUNK_SIZE | 4096 | Tamano de chunk para OTG |

#### Flujo de push
```
Host                                  Device
  |                                      |
  |-- OPEN(localId=1, "sync:") -------->|
  |<-- OKAY(remoteId=10, localId=1) ----|
  |                                      |
  |-- WRTE(localId=1, remoteId=10) ---->|  Payload: "SEND" + 4B LE len + "/data/local/tmp/scrcpy-server.jar,33188"
  |<-- OKAY ----------------------------|
  |                                      |
  |-- WRTE: "DATA" + 4B LE 4096 + chunk1 ->|
  |<-- OKAY ----------------------------|
  |-- WRTE: "DATA" + 4B LE 4096 + chunk2 ->|
  |<-- OKAY ----------------------------|
  |-- ... (repetir por cada chunk) -----|
  |                                      |
  |-- WRTE: "DONE" + 4B zeros --------->|
  |<-- OKAY (o FAIL) -------------------|
  |                                      |
  |-- CLSE ---------------------------->|
```

#### Implementacion
- Chunks de **4096 bytes** (estabilidad OTG phone-to-phone)
- Sleep de **25ms** entre chunks para evitar bus resets
- Retry logic: maxRetries=2 en caso de fallo
- Validacion de respuestas FAIL tempranas durante envio de DATA

### Ejecucion del server

#### Comando
```
CLASSPATH=/data/local/tmp/scrcpy-server.jar \
  app_process / com.genymobile.scrcpy.Server 2.7 \
  tunnel_forward=true \
  audio=false \
  control=true \
  log_level=debug
```

#### Opciones validas (v2.7)
| Opcion | Valor | Descripcion |
|--------|-------|-------------|
| `tunnel_forward` | `true` | Server crea LocalServerSocket y escucha |
| `audio` | `false` | Deshabilita captura de audio |
| `control` | `true` | Habilita el segundo socket para touch y teclas |
| `log_level` | `debug` | Logging detallado |
| `send_dummy_byte` | `true` | Envio de byte 0x00 al conectar (default) |
| `send_device_meta` | `true` | Envio de nombre de device (default) |
| `send_codec_meta` | `true` | Envio de codec + resolucion (default) |

#### startPersistentShell
El server se ejecuta via `startPersistentShell()` que mantiene el stream `shell:` abierto. Si se cerrara, el proceso server moriria inmediatamente.

```kotlin
fun startPersistentShell(command: String, timeoutMs: Long = 10000): Int
```

### Archivos clave
- `UsbAdbTransport.kt` - `pushFile()`, `shellCommand()`, `startPersistentShell()`
- `UsbPlugin.kt` - MethodChannel handlers: `pushFile`, `shellCommand`, `startPersistentShell`
- `adb_client.dart` - `pushFile()`, `shellCommand()`, `startPersistentShell()`, `readAsset()`
- `usb_device_list_page.dart` - UI: log panel con pasos 1-5 visibles

---

## Fase 5: Conexion al Socket scrcpy y Device Info

### Objetivo
Conectar al socket abstracto `localabstract:scrcpy` del server y leer el header de informacion del device (nombre, resolucion, codec).

### Protocolo v2.7 - Device Info Header

El server envia **77 bytes** de header despues de aceptar la conexion:

| Offset | Tamano | Campo | Encoding |
|--------|--------|-------|----------|
| 0 | 1 byte | Dummy byte | Siempre 0x00 |
| 1 | 64 bytes | Device name | UTF-8 null-padded |
| 65 | 4 bytes | Codec ID | Big-endian int (FourCC) |
| 69 | 4 bytes | Screen width | Big-endian int |
| 73 | 4 bytes | Screen height | Big-endian int |

**Total: 77 bytes**

### Flujo de conexion
```
Host (app)                              Device (server)
    |                                      |
    |-- OPEN(localId=N, "localabstract:scrcpy") -->|
    |<-- OKAY(remoteId=M, localId=N) -----|
    |                                      |
    |<-- 1 byte: 0x00 (dummy) ------------|  (despues de accept)
    |<-- 64 bytes: device name ------------|  (sendDeviceMeta)
    |<-- 12 bytes: codec + resolution ----|  (sendCodecMeta)
    |                                      |
    |== Stream abierto para video frames ==|
```

### Codigo Dart (connectScrcpySockets)
```dart
Future<Map<String, dynamic>> connectScrcpySockets() async {
  // 1. Abrir socket
  final streamInfo = await openStream('localabstract:scrcpy', timeoutMs: 10000);
  final localId = streamInfo['localId'] as int;

  // 2. Leer dummy byte (1 byte)
  final dummy = await _readExact(localId, 1);

  // 3. Leer device name (64 bytes)
  final nameBytes = await _readExact(localId, 64);
  final nameEnd = nameBytes.indexWhere((b) => b == 0);
  final deviceName = String.fromCharCodes(nameBytes.sublist(0, nameEnd > 0 ? nameEnd : 64));

  // 4. Leer codec metadata (12 bytes: 4B codec + 4B width + 4B height)
  final codecMeta = await _readExact(localId, 12);
  final codecId = (codecMeta[0] << 24) | (codecMeta[1] << 16) | (codecMeta[2] << 8) | codecMeta[3];
  final width = (codecMeta[4] << 24) | (codecMeta[5] << 16) | (codecMeta[6] << 8) | codecMeta[7];
  final height = (codecMeta[8] << 24) | (codecMeta[9] << 16) | (codecMeta[10] << 8) | codecMeta[11];

  return {'deviceName': deviceName, 'width': width, 'height': height, 'codec': codecFourcc, 'localId': localId};
}
```

### Helper _readExact
Acumula datos de multiples paquetes WRTE hasta completar N bytes exactos:
```dart
Future<List<int>> _readExact(int localId, int n, {int timeoutMs = 5000}) async {
  final buffer = <int>[];
  while (buffer.length < n) {
    final result = await readStream(localId, timeoutMs: timeoutMs);
    if (result['data'] != null) buffer.addAll(result['data']);
    if (result['closed'] == true) throw Exception('Stream closed (${buffer.length}/$n bytes)');
  }
  return buffer;
}
```

### Resultado exitoso
```
Starting Phase 4: Push & Execute scrcpy-server...
[1/4] Reading scrcpy-server from assets...
  Read 71200 bytes
[2/4] Writing to temp file...
  Temp: /data/user/0/com.fiscalia.file_cast/code_cache/scrcpy-server.jar
[3/4] Pushing to /data/local/tmp/scrcpy-server.jar...
  Push success: true
[4/5] Executing scrcpy-server...
  Server shell stream: localId=2
[5/5] Connecting to video socket...
  Device: SM-T505
  Screen: 1200x2000
  Codec: h264
```

### Bugs corregidos

#### 1. v3.3.4 - Opciones invalidas
v3.3.4 no reconoce `no_audio` ni `no_control`. El server imprime warning y puede fallar durante init de MediaCodec/AudioRecord.

Fix: Usar v2.7 con opciones validas `audio=false control=true`.

#### 2. v3.3.4 - Server hang despues de dummy byte
Con v3.3.4, el server enviaba el dummy byte pero nunca el device info. El server colgaba durante MediaCodec init.

Fix: Migrar a v2.7 donde el protocolo funciona correctamente.

#### 3. Shell stream se cierra y server muere
Si se cierra el stream `shell:` donde corre el server, el proceso muere.

Fix: Usar `startPersistentShell()` que mantiene el stream abierto.

#### 4. tunnel_forward semantics
- `tunnel_forward=true`: Server crea `LocalServerSocket` y hace `accept()`. El host se conecta como client.
- `tunnel_forward=false`: Requiere `adb reverse` (host escucha, server se conecta). No viable para OTG phone-to-phone.

#### 5. CNXN payload drain (ya documentado en Fase 3)
Datos residuales del handshake desincronizan el reader thread.

### Archivos clave
- `UsbAdbTransport.kt` - `openStream()`, `readStream()`, `closeStream()`, `getStream()`
- `UsbPlugin.kt` - MethodChannel handlers: `openStream`, `readStream`, `closeStream`, `startPersistentShell`
- `adb_client.dart` - `openStream()`, `readStream()`, `closeStream()`, `connectScrcpySockets()`, `_readExact()`
- `usb_device_list_page.dart` - UI: push + execute + connect con log completo

---

## Fase 8: Exploración y pull de archivos

La transferencia abre streams `sync:` independientes sobre la misma conexión ADB autenticada. No reinicia el handshake ni detiene el mirror.

```text
LIST path -> DENT... -> DONE
STAT path -> STAT(mode, size, mtime)
RECV path -> DATA... -> DONE
```

- `SyncPacketReader` reconstruye mensajes aunque los límites de ADB `WRTE` no coincidan con los límites del subprotocolo sync.
- `AdbSyncClient` limita rutas a `/sdcard` y sus descendientes, rechaza traversal y no ofrece operaciones de escritura sobre el objetivo. La UI inicia con accesos a `DCIM`, `Pictures`, `Movies` y `Download`, y habilita la raíz compartida completa solo cuando el usuario activa ese alcance.
- Los archivos llegan directamente a `.part` en `filesDir/evidence/<requisitionId>/<sessionId>`, se hashean durante la escritura, ejecutan `fsync` y se renombran al finalizar.
- La vista previa reutiliza `RECV` para un único archivo y escribe en `cacheDir/file_previews`; no registra evidencia y elimina el temporal al cerrar.
- El bridge envía a Flutter únicamente metadatos y progreso. Una cancelación cierra el stream activo y descarta el parcial.
- ADB Sync v1 representa tamaños con 32 bits; esta vertical limita cada archivo a `0xFFFFFFFF` bytes y no implementa reanudación por offset.

## Referencia: Archivos del proyecto

| Archivo | Descripcion |
|---------|-------------|
| `android/.../usb/UsbPlugin.kt` | Plugin MethodChannel + BroadcastReceiver |
| `android/.../usb/UsbAdbTransport.kt` | USB bulk, handshake, stream multiplexing, push |
| `android/.../sync/AdbSyncClient.kt` | LIST/STAT/RECV, validación de rutas, streaming, hash y finalización |
| `android/.../sync/SyncPacketReader.kt` | Lectura exacta con conservación de excedentes del stream sync |
| `android/.../adb/AdbProtocol.kt` | Constantes + helpers de paquetes ADB |
| `android/.../adb/AdbAuth.kt` | RSA keypair + firma + android_pubkey struct |
| `android/.../adb/AdbMessage.kt` | AdbMessage data class |
| `lib/core/adb/adb_client.dart` | Cliente Dart (singleton, MethodChannel) |
| `lib/core/adb/adb_models.dart` | Modelos UsbDeviceInfo, UsbEvent |
| `lib/.../usb_device_list_page.dart` | UI completa: device list, shell, scrcpy push/execute |
| `assets/scrcpy/scrcpy-server-v2.7.jar` | scrcpy server binary (71200 bytes) |
| `docs/ADB_HANDSHAKE.md` | Este archivo |
