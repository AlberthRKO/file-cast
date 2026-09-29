# Plan de adquisición USB desde iPhone con libimobiledevice

Fecha: 10 de septiembre de 2026

Estado: **plan aprobado para investigación futura; sin implementación**

Prioridad actual: completar y validar el vertical Android existente.

Este documento define cómo investigar e implementar, en una fase posterior, la
transferencia directa de archivos desde un iPhone/iPad objetivo hacia un
inspector Android con File Cast. Debe leerse junto con
[PROJECT_STATUS_AND_FEASIBILITY.md](PROJECT_STATUS_AND_FEASIBILITY.md),
[IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md),
[HARDWARE_REQUIREMENTS.md](HARDWARE_REQUIREMENTS.md) y `AGENTS.md`.

## Decisión de producto

Para el contexto probatorio de File Cast se descartan como flujo principal:

- instalar una aplicación compañera en el dispositivo objetivo;
- exigir una Mac o PC intermedia;
- root, jailbreak, bypass de bloqueo o explotación del dispositivo;
- prometer acceso completo al sistema de archivos de iOS.

La ruta futura será una **prueba de concepto USB con inspector Android como
host**, basada en los protocolos que implementa `libimobiledevice`:

```text
File Cast en Android
  -> Android USB Host / OTG
      -> usbmux
          -> lockdownd + pairing/trust
              -> AFC / House Arrest
                  -> listado y copia de archivos permitidos por iOS
```

El mirror de iPhone seguirá siendo un canal separado:

```text
iPhone -> adaptador de video -> HDMI -> capturadora UVC -> File Cast
```

No se asumirá que mirror UVC y transferencia USB pueden operar simultáneamente
por el único puerto del iPhone. El procedimiento base cambiará físicamente del
canal de video al cable de datos. Cualquier hub o combinación que prometa ambos
canales deberá superar una prueba independiente antes de incorporarse.

## Resultado que se busca

Con el iPhone desbloqueado y la confianza aceptada por su propietario, File Cast
deberá poder:

1. detectar el dispositivo Apple conectado por USB;
2. solicitar permiso USB al operador en Android;
3. mostrar en el iPhone el flujo legítimo de confianza y registrar su resultado;
4. leer identidad técnica y capacidades disponibles;
5. explorar únicamente las ubicaciones expuestas por los servicios autorizados;
6. previsualizar temporalmente un archivo compatible sin registrarlo como
   evidencia;
7. copiar una selección al almacenamiento privado del inspector;
8. calcular SHA-256 durante la transferencia;
9. verificar tamaño, finalizar de forma atómica y ligar el resultado a requisa y
   sesión;
10. conservar un manifiesto de adquisición y eventos de custodia.

La experiencia debe parecerse al navegador Android actual, pero las raíces y
capacidades se obtendrán del dispositivo en tiempo de ejecución. La interfaz no
debe mostrar una opción de “almacenamiento completo” si iOS no la ofrece.

## Alcance real de datos

### Nivel 1 — AFC general

Será el primer objetivo de la PoC. AFC permite listar y leer **partes** del
sistema de archivos publicadas por iOS, normalmente contenido multimedia y
otras ubicaciones compartidas por el sistema. Las carpetas exactas pueden variar
por versión, modelo, estado del dispositivo y contenido local.

Reglas:

- descubrir las raíces; no codificar una lista universal de carpetas;
- operar en modo lectura;
- no asumir que un elemento visible en iCloud está descargado localmente;
- diferenciar `accesible`, `vacío`, `no descargado`, `bloqueado` y `no soportado`;
- preservar nombre, ruta reportada, tamaño y timestamps originales disponibles.

### Nivel 2 — House Arrest / File Sharing

Permite acceder al directorio `Documents` de aplicaciones que hayan habilitado
File Sharing. No concede acceso indiscriminado a todos los sandboxes.

El flujo deberá:

1. consultar las aplicaciones que realmente publican documentos;
2. mostrar cada aplicación como una raíz separada;
3. abrir `VendDocuments` solamente bajo una acción explícita del operador;
4. degradar la capacidad si la aplicación o versión de iOS la rechaza.

### Nivel 3 — backup lógico con MobileBackup2

Se evaluará únicamente después de aprobar AFC. Un backup lógico puede contener
más categorías que el navegador AFC, pero no equivale a una extracción física ni
a acceso root. Tampoco debe presentarse como un simple explorador de carpetas.

Esta fase exige un ADR y procedimiento separados porque:

- puede requerir contraseña de backup ya configurada;
- la contraseña no debe registrarse en argumentos, logs o estado Flutter;
- crear o cambiar el cifrado del backup puede modificar configuración del
  dispositivo y queda fuera del flujo de solo lectura;
- el formato necesita manifiesto, parser, clasificación y validación por versión;
- el volumen, duración y espacio temporal son muy superiores a AFC.

La primera versión no habilitará `restore`, cambio de contraseña, instalación,
desinstalación, montaje de imágenes de desarrollo ni modificación de ajustes.

### Fuera de alcance

- datos de aplicaciones que iOS no publique mediante AFC, House Arrest o backup;
- contenido protegido por hardware o no disponible mientras el equipo está
  bloqueado;
- extracción de llaveros o secretos fuera del backup autorizado;
- recuperación de archivos borrados;
- acceso físico al sistema de archivos;
- control remoto táctil del iPhone;
- evasión de código, contraseña, Activation Lock o USB Restricted Mode;
- iPhone inspector -> iPhone objetivo mediante USB directo.

## Restricciones probatorias

La operación no es de “cero alteración”. Aceptar confianza/emparejamiento puede
crear o actualizar registros en el dispositivo y el inspector. El procedimiento
debe documentar esta modificación inevitable antes de usar el resultado como
evidencia.

Antes de adquirir:

- registrar fundamento/autorización, operador, requisa y sesión;
- fotografiar o documentar estado, fecha, batería y conectores;
- registrar si el equipo estaba bloqueado o desbloqueado;
- registrar si existía confianza previa o fue otorgada durante la sesión;
- no cambiar conectividad, hora, cuenta, backup encryption ni ajustes del target;
- usar modo avión o aislamiento únicamente si el protocolo operativo lo ordena.

Durante y después:

- copiar siempre target -> inspector;
- bloquear en código todas las operaciones AFC de escritura y borrado;
- registrar desconexiones, reintentos, permisos y errores con códigos estables;
- evitar nombres, rutas y contenido sensible en logs generales;
- calcular hash mientras se escribe, ejecutar `fsync` y rename atómico;
- volver a verificar tamaño y hash antes de registrar la evidencia;
- almacenar el original inmutable y producir previews como derivados;
- incluir versiones y hashes de las bibliotecas nativas en el manifiesto.

## Viabilidad técnica en Android

`libimobiledevice` implementa protocolos nativos de iOS sin depender de software
propietario ni requerir jailbreak. Su proyecto declara pruebas en Android, pero
esto **no significa integración inmediata en una APK**: Android no proporciona
`udev`, `systemd` ni el socket global `/var/run/usbmuxd` de un Linux de escritorio.

La PoC debe resolver explícitamente estas capas:

```text
Android UsbManager
  -> permiso y file descriptor del dispositivo
      -> libusb con descriptor autorizado
          -> worker usbmuxd embebido o transporte usbmux compatible
              -> socket privado dentro del proceso/app
                  -> libusbmuxd
                      -> libimobiledevice
```

### Spike obligatorio de transporte

Antes de diseñar toda la feature se compararán dos alternativas:

#### Alternativa A — usbmuxd embebido

- ejecutar el loop de usbmuxd dentro del proceso o servicio de la app;
- entregar a `libusb` el file descriptor aprobado por `UsbManager`;
- publicar un socket Unix privado, nunca `/var/run/usbmuxd`;
- no requerir root, daemon del sistema ni reglas `udev`;
- aislar cierre, detach y cancelación para que no detengan el proceso Flutter.

#### Alternativa B — transporte usbmux propio

- conservar detección y endpoints USB en Kotlin;
- implementar el framing usbmux mínimo necesario;
- exponer a `libimobiledevice` un endpoint compatible y privado;
- evitar distribuir el daemon GPL si la revisión de licencia lo aconseja.

No se escogerá una alternativa hasta demostrar en hardware:

- attach/detach repetible;
- lectura y escritura USB sin root;
- pairing;
- apertura concurrente de lockdownd y AFC;
- cancelación sin crash;
- reconexión conservando o revocando correctamente la confianza.

## Dependencias nativas previstas

Versionar por commit/tag aprobado y compilar de forma reproducible:

- `libusb`;
- `libplist`;
- `libimobiledevice-glue`;
- `libusbmuxd`;
- `usbmuxd` o el transporte compatible elegido;
- `libimobiledevice`;
- proveedor TLS aprobado, preferentemente el ya soportado por el stack elegido.

La PoC empezará con `arm64-v8a`. Otras ABI se habilitarán solamente si pertenecen
a la matriz real. Cada `.so` deberá tener hash, versión, símbolos controlados y
registro en SBOM.

### Gate de licencias

Este gate es previo a distribuir la funcionalidad. `libimobiledevice` y
`libusbmuxd` se publican bajo LGPL-2.1; el daemon `usbmuxd` usa licencias GPL.
Se requiere revisión legal de linking, modificaciones, avisos y entrega de código
fuente correspondiente. Una PoC técnica interna no autoriza silenciosamente su
distribución en una aplicación cerrada.

## Arquitectura de File Cast

Se conserva la dirección obligatoria:

```text
View
  -> ViewModel
      -> Use Case
          -> IosUsbAcquisitionRepository
              -> IosUsbAcquisitionRepositoryImpl
                  -> IosUsbAcquisitionPlatformService
                      -> plugin Kotlin/JNI
                          -> stack nativo libimobiledevice
```

La View no manejará USB, rutas remotas, archivos, hashes ni códigos nativos. El
ViewModel no recibirá `BuildContext` ni navegará. El servicio de plataforma será
la única frontera Flutter/nativa.

### Estructura prevista

```text
lib/
├── domain/
│   ├── models/
│   │   └── ios_usb/                 # device, capability, entry, transfer, pairing
│   ├── repositories/
│   │   └── ios_usb_acquisition_repository.dart
│   └── use_cases/acquisition/
│       ├── connect_ios_usb_device.dart
│       ├── browse_ios_shared_files.dart
│       └── import_ios_evidence.dart
├── data/
│   ├── models/ios_usb/              # DTO de la frontera nativa
│   ├── repositories/
│   │   └── ios_usb_acquisition_repository_impl.dart
│   └── services/platform/
│       └── ios_usb_acquisition_platform_service.dart
└── ui/features/acquisition/ios_transfer/
    ├── view_models/
    ├── views/
    └── widgets/

android/app/src/main/kotlin/com/fiscalia/file_cast/iosdevice/
├── IosUsbPlugin.kt                  # API tipada hacia Flutter
├── IosUsbSession.kt                 # ciclo de vida por sessionId
├── usb/AndroidUsbBridge.kt          # UsbManager, permisos y detach
├── pairing/PairingStore.kt          # secretos protegidos con Keystore
├── afc/IosAfcBridge.kt              # list/stat/read solamente
├── backup/IosBackupBridge.kt        # fase opcional posterior
└── diagnostics/IosUsbLogger.kt      # redacción y códigos estables

android/app/src/main/cpp/ios_device/
├── CMakeLists.txt
├── jni_bridge.cpp
├── usbmux_runtime/
└── third_party/                     # fuentes fijadas o integración reproducible
```

Los snapshots de dominio, DTO y estado nuevos usarán Freezed. Los DTO de la
frontera nativa deberán estar versionados; no se perpetuará un contrato de mapas
y strings libres.

## Contrato de capacidades

El repositorio publicará capacidades observadas, no inferidas únicamente por
modelo o versión:

```text
canReadDeviceInfo
canBrowseAfc
canBrowseFileSharingApps
canPreview
canPullFiles
canCreateLogicalBackup
requiresUnlock
requiresTrust
backupIsEncrypted
```

Estados mínimos de sesión:

```text
idle
detecting
requestingUsbPermission
waitingForUnlock
waitingForTrust
pairing
connected
browsing
previewing
transferring
canceling
detached
trustRevoked
unsupported
error
```

Todo comando incluirá `requisitionId`, `sessionId` y el identificador opaco del
dispositivo. Un evento atrasado de una sesión no podrá actualizar otra sesión.

## Pairing y secretos

El flujo inicial será:

1. Android detecta un dispositivo Apple y obtiene permiso USB.
2. File Cast abre usbmux y lockdownd.
3. Si no existe pairing válido, solicita el handshake.
4. El operador desbloquea el iPhone y acepta “Confiar”.
5. File Cast verifica la sesión antes de habilitar browsing.
6. El pair record se guarda cifrado mediante Android Keystore, asociado al
   inspector y al identificador del target.
7. Al cerrar la sesión se liberan descriptores y clientes; el registro se conserva
   o elimina según la política institucional.

Los pair records, certificados y claves son secretos. No irán a
`SharedPreferences` sin cifrado, logs, analytics, estado serializable de Flutter
ni backups generales del inspector.

La UI debe ofrecer una acción administrativa de revocación local y explicar que
restablecer “Localización y privacidad” en el iPhone invalida la confianza.

## Browser, preview y transferencia

### Listado

- usar paginación/ventanas aun si AFC entrega listas completas;
- ordenar localmente sin alterar el target;
- normalizar para UI sin cambiar el nombre original conservado en metadatos;
- impedir `..`, traversal y escapes fuera de la raíz otorgada;
- no seguir enlaces ni tipos desconocidos hasta validarlos;
- imponer límites de profundidad, cantidad y tamaño de metadatos.

### Preview

- copiar a `cacheDir/ios_previews/<sessionId>` con límite configurable;
- calcular hash temporal solo para trazabilidad diagnóstica;
- nunca registrar automáticamente un preview como evidencia;
- reutilizar los visores actuales de imagen, video, audio, PDF, DOCX y texto;
- eliminar el temporal al cerrar, cancelar, desconectar o expirar la sesión;
- mostrar “preview no soportado” sin descargar archivos excesivos.

### Importación probatoria

```text
AFC read
  -> archivo <uuid>.part en almacenamiento privado
      -> SHA-256 incremental + conteo de bytes
          -> fsync
              -> validar tamaño
                  -> rename atómico
                      -> Evidence + CustodyEvent + Outbox
```

- transferencia secuencial inicial para reducir presión USB;
- progreso por archivo y total;
- cancelación cooperativa y cleanup idempotente;
- no reanudar por offset hasta demostrar que el servicio y la verificación lo
  soportan de forma segura;
- deduplicar por hash sin perder el evento que acredita una nueva adquisición;
- conservar el path reportado como metadata, nunca como ruta local directa.

## Metadatos mínimos de evidencia iOS

Además del modelo común de `Evidence`:

```text
acquisitionMethod: iosUsbAfc | iosHouseArrest | iosLogicalBackup
sourceDeviceUdidHash
sourceProductType
sourceOsVersion
sourcePath
sourceAppBundleId?
sourceSize
sourceCreatedAt?
sourceModifiedAt?
usbVendorId/productId
trustWasPreexisting
trustGrantedAtUtc?
transferStartedAtUtc
transferCompletedAtUtc
nativeStackVersions
nativeBinaryHashes
cableInventoryId
inspectorDeviceId
```

El UDID completo solo se conservará donde la política de identificación lo
autorice. En logs y telemetría se usará una representación truncada o derivada.

## Errores y recuperación

Definir códigos estables, al menos:

```text
iosUsbPermissionDenied
iosDeviceLocked
iosTrustRequired
iosTrustDenied
iosPairingInvalid
iosPairingRecordMissing
iosUsbMuxUnavailable
iosLockdownUnavailable
iosAfcUnavailable
iosPathNotAccessible
iosFileNotLocal
iosTransferCanceled
iosDeviceDetached
iosInsufficientInspectorStorage
iosSourceChangedDuringRead
iosHashVerificationFailed
iosBackupPasswordRequired
iosBackupUnsupported
```

Ante detach se cancelan operaciones, se cierran handles una sola vez, se elimina
el `.part` y se conserva un evento de sesión. Una reconexión nunca continuará una
transferencia como si fuera el mismo stream sin revalidar dispositivo, sesión,
ruta, tamaño y metadata.

## Hardware para la PoC

### Inspector

- Android homologado con USB Host/OTG real;
- USB-C 3.x recomendado;
- 8 GiB RAM y 256 GiB de almacenamiento recomendados;
- Android Keystore disponible;
- hub OTG/USB-C alimentado para pruebas de energía y sesiones largas.

### Cables

- iPhone Lightning: cable Lightning de datos original o certificado MFi;
- iPhone USB-C: cable USB-C de datos certificado, no solo carga;
- adaptador USB-C OTG a USB-A cuando el cable lo requiera;
- dos unidades identificadas de cada modelo aprobado.

MHL no interviene. La capturadora Elgato tampoco transfiere archivos; pertenece
exclusivamente al canal de mirror.

## Fases de implementación futura

### Fase 0 — investigación, licencia y laboratorio

- congelar el alcance AFC de solo lectura;
- seleccionar commits/tags y generar SBOM;
- aprobar la estrategia de licencias;
- preparar fixtures conocidos y dispositivos de prueba;
- medir enumeración USB y viabilidad del descriptor `UsbManager` -> `libusb`;
- elegir usbmuxd embebido o transporte compatible propio.

**Salida:** ADR de transporte y demo nativa que enumera un iPhone sin root.

### Fase 1 — transporte USB y ciclo de vida

- plugin Kotlin aislado del plugin ADB;
- permisos, attach/detach y foreground lifecycle;
- runtime C/C++ por JNI;
- timeouts, cancelación y cleanup idempotente;
- eventos tipados hacia Dart.

**Salida:** 20 conexiones y desconexiones consecutivas sin crash ni handles
huérfanos.

### Fase 2 — lockdownd, identidad y pairing

- consulta de identidad no sensible;
- estados de unlock/trust;
- pairing nuevo y reutilización controlada;
- pair records cifrados con Keystore;
- revocación y recuperación de confianza inválida.

**Salida:** conectar un equipo nuevo, uno ya confiado y uno con confianza
revocada, sin confundir sesiones.

### Fase 3 — AFC y House Arrest de solo lectura

- descubrir raíces AFC;
- `list`, `stat`, `open/read/close`;
- enumerar aplicaciones con File Sharing;
- protección de rutas y límites;
- preview temporal.

**Salida:** listar y previsualizar fixtures conocidos sin escribir en el target.

### Fase 4 — integración probatoria

- repositorio, casos de uso y ViewModel;
- selección múltiple, progreso y cancelación;
- almacenamiento `.part`, hash, `fsync` y rename;
- registro `Evidence`, ledger y outbox;
- galería de detalle y previews derivados.

**Salida:** archivos transferidos con hash verificado y vinculados a
`requisitionId`/`sessionId`.

### Fase 5 — hardening y validación física

- archivos de 0 B, grandes, Unicode y nombres hostiles;
- lotes extensos y poco espacio;
- bloqueo, background, detach y reconexión;
- USB Restricted Mode y confianza reiniciada;
- matriz Lightning/USB-C y versiones mínima/intermedia/actual;
- soak test y comparación byte a byte con fixtures.

**Salida:** matriz aprobada y límites publicados en la UI/manual.

### Fase 6 — MobileBackup2 opcional

- ADR específico;
- backup completo autorizado, nunca restore;
- contraseña manejada en memoria protegida;
- parser y manifiesto del backup;
- estimación de espacio/tiempo y cancelación segura;
- validación jurídica y forense separada.

**Salida:** decisión de incorporar o descartar backup lógico. Esta fase no
bloquea la entrega AFC.

## Matriz mínima de validación

- iPhone Lightning antiguo dentro del soporte institucional;
- iPhone Lightning reciente;
- iPhone USB-C con velocidad USB 2;
- iPhone USB-C con velocidad USB 3;
- versión iOS mínima, intermedia y actual aprobada;
- dispositivo recién confiado, ya confiado y confianza revocada;
- bloqueado/desbloqueado antes y durante una lectura;
- backup encryption desactivado/activado, solo para la fase MobileBackup2;
- inspector Android compacto y tablet homologada;
- conexión directa, OTG y hub alimentado aprobados.

Para cada combinación registrar:

1. IDs de inventario de inspector, target, cable y hub;
2. versiones de OS, app y stack nativo;
3. tiempo de detección, pairing y listado;
4. 20 ciclos de attach/detach;
5. transferencia de 0 B, 1 MB, 1 GB y lote de archivos pequeños;
6. cancelación y desconexión en cada etapa;
7. hash del fixture antes y después;
8. cambios observados en el target;
9. temperatura, consumo y estabilidad;
10. resultado reproducible y limitaciones.

## Gates de decisión

No se avanzará al siguiente nivel si falla cualquiera de estos gates:

1. **USB:** Android obtiene acceso sin root y sobrevive a reconexiones.
2. **Pairing:** el flujo de confianza es visible, repetible y auditable.
3. **Lectura:** AFC lista y copia fixtures sin operaciones de escritura.
4. **Integridad:** los bytes y SHA-256 coinciden con la fuente conocida.
5. **Custodia:** cada artefacto queda ligado a requisa/sesión y manifiesto.
6. **Licencia:** la distribución del stack nativo está aprobada.
7. **Matriz:** Lightning y USB-C cumplen el umbral de estabilidad acordado.

Si AFC falla en la matriz, File Cast mostrará la capacidad como no disponible;
no se reemplazará silenciosamente por un flujo inseguro o una promesa de acceso
completo.

## Riesgos principales

| Riesgo | Mitigación |
|---|---|
| usbmuxd fue diseñado como daemon de escritorio | Spike con socket privado y FD autorizado por Android |
| cambios de iOS rompen servicios no documentados públicamente | Versiones fijadas, matriz y capability negotiation |
| el usuario interpreta AFC como almacenamiento completo | Etiquetas de “contenido accesible” y límites visibles |
| pair record expuesto | Keystore, cifrado, sin backup/log y revocación |
| modificación involuntaria del target | API nativa allowlist de solo lectura y auditoría |
| archivo cambia durante la copia | Comparar metadata antes/después y fallar la adquisición |
| desconexión deja evidencia parcial | `.part`, cleanup idempotente y evento de interrupción |
| consumo/licencia de dependencias nativas | ABI mínima, SBOM, revisión legal y hashes |
| un solo puerto impide mirror + datos | flujo secuencial documentado; no prometer simultaneidad |

## Criterio de finalización

La transferencia iPhone se considerará lista para piloto solamente cuando:

- funcione sin Mac/PC, app compañera, jailbreak ni root del inspector;
- el iPhone muestre y acepte explícitamente la confianza;
- las capacidades y límites estén visibles;
- el stack sea estable en la matriz Lightning/USB-C;
- no existan operaciones de escritura habilitadas hacia el target;
- los originales se almacenen de forma privada, atómica e inmutable;
- tamaño y SHA-256 hayan sido verificados;
- requisa, sesión, dispositivo, operador y herramienta queden en el manifiesto;
- licencias y SBOM estén aprobados;
- el procedimiento haya sido validado jurídica y forénsicamente.

## Fuentes técnicas

- [libimobiledevice — repositorio oficial](https://github.com/libimobiledevice/libimobiledevice)
- [usbmuxd — repositorio oficial](https://github.com/libimobiledevice/usbmuxd)
- [libusbmuxd — repositorio oficial](https://github.com/libimobiledevice/libusbmuxd)
- [libusb en Android](https://github.com/libusb/libusb/tree/master/android)
- [afcclient — acceso AFC/House Arrest](https://cgit.libimobiledevice.org/libimobiledevice.git/tree/docs/afcclient.1)
- [idevicebackup2 — backup lógico](https://github.com/libimobiledevice/libimobiledevice/blob/master/docs/idevicebackup2.1)
- [Apple — confiar en un dispositivo conectado](https://support.apple.com/en-euro/109054)
- [Apple — File Sharing y sus límites](https://support.apple.com/en-us/120402)
- [NIST SP 800-101 Rev. 1 — Mobile Device Forensics](https://csrc.nist.gov/pubs/sp/800/101/r1/final)
