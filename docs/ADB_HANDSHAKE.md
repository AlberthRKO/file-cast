# ADB Handshake - Fase 1 y 2

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
