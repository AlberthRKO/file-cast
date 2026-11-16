# Plan de implementación de captura HDMI/UVC

Fecha de análisis: 16 de noviembre de 2026

Estado: **plan técnico; funcionalidad no implementada**

Revisión de alcance: iPad Air 4 con iPadOS 27 incorporado como inspector UVC y
capturadora UGREEN concreta identificada. Se documenta además el uso posterior
de un hub ORICO USB-C, sin confundir enumeración de varios USB con soporte de
varios mirrors simultáneos.

Prioridad recomendada: PoC directa con la misma capturadora UGREEN en inspector
Android y en iPad Air 4, sin modificar el flujo estable ADB/scrcpy.

Este documento define la ampliación de File Cast para recibir una salida HDMI
de un teléfono objetivo mediante una capturadora USB Video Class (UVC), mostrarla
en el inspector y crear capturas de frame y grabaciones ligadas a una requisa y
sesión. Debe leerse junto con:

- [PROJECT_STATUS_AND_FEASIBILITY.md](PROJECT_STATUS_AND_FEASIBILITY.md);
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md);
- [HARDWARE_REQUIREMENTS.md](HARDWARE_REQUIREMENTS.md);
- [ADB_HANDSHAKE.md](ADB_HANDSHAKE.md);
- [IOS_USB_LIBIMOBILEDEVICE_PLAN.md](IOS_USB_LIBIMOBILEDEVICE_PLAN.md);
- [HDMI_UVC_CABLE_CONNECTION_GUIDE.md](HDMI_UVC_CABLE_CONNECTION_GUIDE.md);
- [ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md](ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md);
- [modules/acquisition_capture.md](modules/acquisition_capture.md);
- `AGENTS.md` y las skills Flutter del repositorio.

> Límite de ejecución: este plan no autoriza `flutter test`, `flutter analyze`,
> `flutter run`, builds nativos ni generadores. La validación física y las
> compilaciones quedan reservadas al propietario.

## Dictamen ejecutivo

La capturadora no conoce si la fuente HDMI es Android o iPhone. Si el objetivo
puede producir una señal HDMI compatible y el inspector puede abrir la
capturadora UVC, el mismo pipeline de entrada sirve para ambos objetivos.

La frontera real está en cada extremo:

1. **Inspector Android:** la capturadora debe recibir objetivos iPhone o Android
   con salida HDMI. Android conserva además Mirror y Transferencia por ADB.
2. **Inspector iPad Air 4, USB-C, iPadOS 27:** pasa a ser plataforma requerida
   para Capturadora. Apple permite cámaras UVC externas en iPadOS mediante
   AVFoundation desde iPadOS 17, y la ficha de la capturadora declara iPadOS 17+
   como compatible.
3. **Objetivo Android:** funciona por capturadora solamente si ofrece salida de
   video USB-C DisplayPort Alt Mode o un adaptador MHL/SlimPort específico.
4. **Objetivo iPhone:** Lightning usa Apple Lightning Digital AV Adapter; USB-C
   usa USB-C -> HDMI.
5. **iPhone como inspector:** permanece fuera de alcance; no se compilará como
   terminal UVC en esta etapa.

El docking Revodok/Vention no forma parte del alcance actual. La primera matriz
usa conexión directa de la capturadora al inspector. El hub ORICO aportado se
incorpora en dos alcances distintos: usarlo como OTG para **un solo Android ADB**
es el primer gate; usarlo para dos y tres mirrors simultáneos es el objetivo
multisesión obligatorio, aunque todavía no está implementado por el código
actual. La arquitectura será dinámica N: tres es la primera homologación por el
ORICO, no el máximo de software; un hub de seis puertos agrega una matriz 4/5/6.

## Garantía de no regresión de Mirror y Transferencia

La feature Capturadora no reemplaza ni reescribe los verticales que ya
funcionan. El orden de implementación debe protegerlos con estas reglas:

1. conservar `UsbAdbTransport`, `ScrcpyDecoder`, `ScrcpyControl`,
   `ScrcpyRecorder` y `AdbSyncClient` durante la PoC UVC;
2. crear plugin, servicio, repositorio y rutas UVC separados antes de extraer
   cualquier contrato común;
3. mantener las rutas actuales de Mirror y Transferencia, incluidos
   `requisitionId` y `sessionId`;
4. no cambiar comandos, handshake, sockets, formato H.264, coordenadas de
   control ni semántica ADB como efecto lateral de Capturadora;
5. registrar receivers y handles por transporte y `deviceId`, de modo que
   retirar una capturadora no cierre ADB y retirar otro USB del hub no cierre la
   sesión activa;
6. ejecutar una matriz de regresión física de Mirror, control, captura,
   grabación y transferencia antes de aceptar cada fase UVC.

La Fase 1 adapta scrcpy detrás de un contrato solamente después de fijar pruebas
de caracterización. Si esa adaptación cambia el comportamiento observado, se
revierte el adaptador y UVC continúa aislado. Por tanto, el plan no exige
modificar lo que hoy funciona para demostrar la capturadora.

## Las cuatro opciones de File Cast

El detalle de la requisa debe presentar cuatro acciones distintas y estables:

| Acción | Transporte | Propósito | Inspector Android | iPad Air 4 |
|---|---|---|---|---|
| **Mirror** | ADB + scrcpy | Ver y controlar un Android objetivo | Disponible | No disponible |
| **Transferencia de archivos** | ADB Sync; AFC futuro | Copiar archivos permitidos desde el objetivo | Android disponible; iPhone futuro | No disponible desde otro teléfono |
| **Capturadora** | HDMI -> UVC | Ver Android/iPhone y crear captura/grabación de esa señal | Requerida | Requerida |
| **Importar archivos** | Selector del sistema | Incorporar archivos locales del inspector | Disponible | Disponible |

Las cuatro tarjetas pueden permanecer visibles en Android y iPad. La UI las
habilita por capacidades observadas y muestra una explicación en las no
disponibles; no debe ocultar el alcance ni hacer que Capturadora parezca una
variante de Mirror.

Dentro de **Capturadora** existirán las mismas intenciones de evidencia que el
workspace actual:

- **Capturar imagen:** toma el siguiente frame UVC completo posterior al toque;
- **Grabar video / Detener:** crea un MP4 desde la señal UVC;
- galería y estados FCE/outbox comunes;
- diagnóstico propio de señal, formato, FPS, frames descartados y audio.

El decoder y recorder scrcpy Kotlin actuales se conservan para Mirror. UVC tendrá
su propio decoder/recorder en Android y AVFoundation/AVAssetWriter en iPad,
detrás del mismo contrato Dart.

## Matriz de escenarios

Leyenda:

- **Sí:** técnicamente viable y dentro del producto propuesto.
- **Condicional:** requiere una capacidad concreta del modelo o una PoC.
- **No:** el transporte no ofrece esa capacidad.
- **Futuro:** existe plan separado, todavía sin implementación.

| Inspector | Objetivo | Transporte | Ver pantalla | Capturar frame | Grabar video | Controlar objetivo | Transferir archivos | Dictamen |
|---|---|---|---:|---:|---:|---:|---:|---|
| Android | Android 5+ | USB OTG + ADB/scrcpy | Sí | Sí, `screencap` | Sí, H.264 scrcpy | Sí, sujeto a fabricante | Sí, almacenamiento accesible | Ya implementado como vertical local |
| Android | Android con salida HDMI | USB-C/DP Alt Mode o MHL/SlimPort -> HDMI -> UVC | Condicional | Sí, frame recibido | Sí, señal recibida | No | No por UVC | Nueva feature viable; ADB sigue siendo superior cuando está disponible |
| Android | iPhone Lightning | Lightning Digital AV -> HDMI -> UVC | Sí | Sí, frame recibido | Sí, señal recibida | No | No por UVC | Nueva feature viable; hasta 1080p con adaptador Apple |
| Android | iPhone USB-C | USB-C -> HDMI -> UVC | Sí | Sí, frame recibido | Sí, señal recibida | No | No por UVC | Nueva feature viable; negociar una señal soportada por la capturadora |
| Android | iPhone | USB de datos + AFC | No | No | No | No | Futuro, contenido permitido | Plan separado `IOS_USB_LIBIMOBILEDEVICE_PLAN.md` |
| iPhone | Android con salida HDMI | HDMI -> capturadora UVC genérica | No | No | No | No | No | No viable como baseline: iPhone no expone UVC genérico a AVFoundation |
| iPhone | iPhone | HDMI -> capturadora UVC genérica | No | No | No | No | No | No viable como baseline por la misma limitación del inspector |
| iPhone | Archivos locales del inspector | Selector del sistema | No aplica | No aplica | No aplica | No | Sí, archivos seleccionados | Ya permitido por File Cast |
| iPad Air 4/iPadOS 27 | Android con salida HDMI | HDMI -> UVC | Sí, pendiente de PoC física | Sí | Sí | No | No | Plataforma requerida mediante AVFoundation |
| iPad Air 4/iPadOS 27 | iPhone Lightning/USB-C | HDMI -> UVC | Sí, pendiente de PoC física | Sí | Sí | No | No | Plataforma requerida mediante AVFoundation |

### Qué significa “captura” en cada transporte

No se deben presentar como equivalentes dos métodos con distinta procedencia:

| Método | Bytes adquiridos | Semántica correcta |
|---|---|---|
| `ANDROID_ADB_SCREENCAP` | PNG producido por el Android objetivo | Captura de pantalla del objetivo |
| `ANDROID_SCRCPY_H264_RECORDING` | H.264 generado en el Android objetivo y remultiplexado por el inspector | Grabación del stream de pantalla |
| `HDMI_UVC_FRAME_CAPTURE` | Frame recibido después de salida de video, HDMI, capturadora y conversión UVC | Captura de frame de la señal HDMI/UVC |
| `HDMI_UVC_RECORDING` | Video recibido o recodificado por el inspector | Grabación de la señal HDMI/UVC |

El hash HDMI/UVC acredita el archivo creado por el inspector. No es el hash de
un framebuffer original del objetivo. La cadena HDMI puede cambiar resolución,
color, rango dinámico, escala, orientación, frecuencia y audio.

## Evaluación del hardware disponible

La dirección de la señal es:

```text
objetivo (salida de video)
  -> adaptador/cable a HDMI
    -> cable HDMI macho-macho
      -> HDMI IN de la capturadora
        -> USB UVC de la capturadora
          -> puerto USB Host del inspector
```

La primera implementación usará conexión directa. Revodok, Vention y otros
dockings quedan excluidos hasta una fase posterior solicitada expresamente. El
ORICO enlazado por el propietario se probará después del baseline directo como
hub de datos/energía; su HDMI es una **salida** del inspector, no una entrada
para la capturadora.

### Capturadora UGREEN confirmada

La fotografía y la ficha aportada identifican una capturadora UGREEN con HDMI
hembra y salida USB integrada USB-C/USB-A. La ficha declara:

- HDMI 1.4 e input máximo 4K30;
- captura máxima 2K30 y retrocompatibilidad 1080p60;
- USB 3.0 hasta 5 Gbps;
- video y audio;
- latencia anunciada aproximada de 130 ms;
- Android e iPadOS 17+;
- sin HDMI loop-out;
- sin HDCP, HDR ni 3D;
- iPhone 15/16 no compatible como terminal de captura.

El SKU no aparece en la ficha boliviana ni en la cara fotografiada. Se registrará
el modelo/serial que reporte USB en la Fase 0 y no se confundirá con variantes
UGREEN que sí poseen loop-out.

| Elemento disponible | Uso válido | No resuelve | Observación/gate |
|---|---|---|---|
| HDMI macho-macho | Adaptador del objetivo -> HDMI IN de capturadora | USB, datos o control | Homologar longitud, versión y estabilidad |
| USB-C a USB-C 10 Gbps/240 W | ADB/AFC directo o pruebas de datos | Capturadora -> inspector | La capturadora ya incorpora su propio USB-C macho; no necesita este cable |
| USB-A a USB-C | ADB/AFC o adaptaciones de datos | Salida HDMI del objetivo | La capturadora usa su conector integrado; preferir conexión directa USB-C |
| Lightning a USB-C / Lightning a USB-A | Futuro enlace de datos AFC o carga | Mirror HDMI | No transporta por sí solo la pantalla hacia una capturadora HDMI |
| USB-C a HDMI 2.1 | Salida de iPhone USB-C o Android con DP Alt Mode -> capturadora | Android sin salida de video | Verificar que sea direccional USB-C source -> HDMI display |
| OTG USB-C a USB-A hembra | Inspector Android como host de una capturadora USB-A | Salida HDMI del target | Debe mantener rol host y energía estable |
| OTG Micro-USB a USB-A hembra | Inspector Android antiguo como host | Ancho de banda/energía garantizados | Solo PoC; alto riesgo de USB 2, energía y calentamiento |
| USB-A a Micro-USB | Enlace de datos/carga donde el accesorio lo requiera | HDMI desde Android antiguo | No sustituye un adaptador MHL/SlimPort |
| Lightning a HDMI genérico | Salida de video de iPhone Lightning | Entrada UVC al inspector | Validar modelo exacto, alimentación, latencia y compatibilidad; preferir Apple original |
| Apple Lightning Digital AV Adapter | Salida HDMI de iPhone Lightning, hasta 1080p | Control o datos AFC | Accesorio recomendado para el target Lightning |
| Capturadora UGREEN confirmada | HDMI IN -> USB UVC/UAC; 2K30 o 1080p60 máximo anunciado | Salida HDMI del objetivo, control o archivos | Conectar su USB-C integrado directamente a Android/iPad; no tiene loop-out |

### Cobertura real del kit

El kit cubre, sujeto a homologación:

- iPhone Lightning objetivo -> inspector Android o iPad Air 4;
- iPhone USB-C objetivo -> inspector Android o iPad Air 4;
- Android con USB-C DisplayPort Alt Mode objetivo -> inspector Android o iPad
  Air 4;
- conexión USB-C directa de la capturadora a ambos inspectores.

No cubre automáticamente:

- Android sin salida de video por USB-C;
- Android Micro-USB que requiera MHL/SlimPort específico;
- iPhone usado como inspector UVC;
- control táctil o transferencia de archivos mediante HDMI/UVC;
- contenido protegido por HDCP;
- mirror HDMI y AFC/ADB simultáneos por el mismo puerto;
- alimentación simultánea mediante docking, fuera del alcance actual.

### Resolución anunciada versus resolución capturada

En el modelo confirmado, 4K30 describe la **entrada**, no la captura. El máximo
anunciado por USB es 2K30 o 1080p60 y no existe passthrough/loop-out. La app debe
leer AVFoundation o los descriptores UVC y mostrar el modo realmente negociado;
nunca debe inferirlo del empaque.

Baseline recomendado para la PoC:

```text
1920x1080 SDR
30 fps estables
video sin audio en la primera fase
MJPEG o YUY2 según descriptor y ancho de banda
```

1080p60, 2K30 y audio UAC se habilitan después del baseline. HDR permanece fuera
de alcance porque la capturadora confirmada lo declara incompatible.

## Hallazgos en el código actual

### Lo que ya existe

- `UsbPlugin.kt` recibe el H.264 de scrcpy, lo decodifica hacia una Flutter
  `Texture` y alimenta `ScrcpyRecorder`.
- La captura actual abre `exec:screencap -p`, escribe PNG directamente en
  almacenamiento privado y calcula SHA-256 en Kotlin.
- La grabación actual remultiplexa el H.264 con `MediaMuxer`, espera un keyframe,
  finaliza `.part`, valida el MP4 y devuelve solo metadata a Dart.
- `AndroidAcquisitionPlatformService` coordina ADB/scrcpy y expone archivos
  terminados a `AcquisitionRepositoryImpl`.
- `AcquisitionRepositoryImpl` registra, cifra y sincroniza la evidencia mediante
  el pipeline común.
- La ruta de mirror recibe `requisitionId` y `sessionId`; el `textureId` viaja
  como argumento efímero tipado.

### Limitaciones para incorporar UVC

1. `AcquisitionRepositoryImpl` depende directamente de
   `AndroidAcquisitionPlatformService`; el contrato todavía supone Android/ADB.
2. `AcquisitionMirrorSession` contiene `controlStreamId`, obligatorio para
   scrcpy pero inexistente en UVC.
3. `UsbPlugin` agrupa USB, ADB, scrcpy, transferencia, captura y grabación.
4. `device_filter.xml` solo declara la interfaz ADB `255/66/1`; no declara UVC.
5. El receiver actual desconecta ADB ante cualquier `USB_DEVICE_DETACHED`, sin
   comprobar si el equipo retirado es el transporte activo. Esto es riesgoso al
   incorporar un segundo tipo de dispositivo USB y cambiar entre sesiones.
6. Android no tiene permisos `CAMERA`/`RECORD_AUDIO`; iOS no tiene
   `NSCameraUsageDescription`/`NSMicrophoneUsageDescription` para una PoC UVC.
7. iOS solo registra plugins generados; no existe servicio Swift de adquisición.
8. Las capacidades de sesión se construyen hoy a partir de
   `sourcePlatform == ANDROID`, no desde capacidades observadas del adaptador.
9. `UsbManager.deviceList` puede enumerar varios periféricos detrás de un hub,
   pero `UsbPlugin` conserva un solo `adbTransport`, un solo
   `currentConnection`, un solo `ScrcpyDecoder` y una sola textura. Conectar un
   segundo objetivo mediante `connectAdb` ejecuta `disconnectAdb()` sobre el
   primero.
10. El receiver actual llama `disconnectAdb()` ante el detach de cualquier USB,
    aunque el periférico retirado sea un mouse, teclado, capturadora u otro
    teléfono del hub.
11. `getConnectedDevices()` devuelve todos los USB enumerados, sin clasificar
    primero la interfaz ADB. Con un hub puede mostrar el propio hub, mouse,
    teclado y otros periféricos como candidatos hasta que se agregue un probe
    de capacidades.

### Dictamen para el hub ORICO y tres mirrors

| Escenario | Hardware | Código actual | Alcance de este plan |
|---|---|---|---|
| Un Android objetivo por un USB-A del ORICO | Viable si el inspector conserva rol host y el cable lleva datos | Debe poder funcionar después de autorizar USB/ADB | Matriz de regresión obligatoria |
| Tres Android enumerados por el ORICO | Posible; Android expone una lista de USB conectados | Puede listarlos, pero no los clasifica de forma segura | Se agrega probe por interfaz/dispositivo |
| Tres mirrors simultáneos | Condicionado por energía, ancho de banda y decoders | **No soportado hoy:** existe una sola sesión global | Alcance obligatorio del plan multisesión 1 -> 2 -> 3 |
| Una UGREEN UVC por el ORICO | Posible por un USB-A de datos usando el adaptador de la capturadora | Aún no existe adaptador UVC | Validar después de UVC directo |
| UVC + un Android ADB conectados al ORICO | Posible de enumerar; falta homologación | El detach global y los singletons pueden romper ADB | No habilitar simultáneo hasta aislar sesiones |

Que el objetivo cargue confirma VBUS, no confirma que Android haya enumerado
una interfaz ADB. Mouse y teclado funcionando demuestran que el inspector está
en modo host, pero no prueban el cable del teléfono, la depuración USB, la
interfaz ADB ni el permiso de File Cast.

### Alcance obligatorio: ORICO como OTG para un solo objetivo

Este caso deja de pertenecer a la fase multisesión opcional. Antes de trabajar
con varios objetivos, Mirror debe soportar esta cadena exacta:

```text
Android inspector
  -> USB-C upstream del ORICO
  -> un USB-A de datos del ORICO
  -> cable USB-A a USB-C de datos
  -> un Android objetivo con ADB habilitado
```

El diagnóstico y el arreglo se dividen en dos gates:

1. **Gate de enumeración Android:** `UsbManager.deviceList` debe contener el
   teléfono y sus descriptores deben incluir una interfaz ADB `255/66/1`. Si el
   teléfono no aparece, ninguna modificación Flutter/Kotlin puede fabricar el
   enlace físico; la app debe reportar `usbDeviceNotEnumerated` y el laboratorio
   debe revisar cable, puerto, rol USB, PD y firmware del hub/teléfonos.
2. **Gate File Cast:** si Android enumera la interfaz ADB, File Cast debe
   clasificar ese dispositivo, pedir permiso sobre ese `deviceId`, abrirlo y
   completar el handshake. Si falla aquí, se considera un defecto corregible
   del plugin o de su selección de dispositivo.

Cambios requeridos para superar el segundo gate:

- incluir interfaces y endpoints USB en el snapshot de diagnóstico nativo;
- clasificar `adb`, `uvc/uac`, `hid`, `storage`, `hub` y `unknown` antes de
  exponer candidatos al repositorio;
- mostrar en Mirror solamente equipos con interfaz ADB exacta; no ofrecer el
  hub, mouse o teclado;
- eliminar el fallback operativo que intenta usar la primera interfaz de un
  dispositivo que no es ADB;
- asociar permiso, attach, detach, handshake y errores al `deviceId` elegido;
- publicar errores distintos para no enumerado, sin interfaz ADB, permiso
  rechazado, claim fallido, handshake fallido y reenumeración;
- conservar el Mirror singular durante MM0/MM1 y usarlo como base de regresión;
  después introducir obligatoriamente el registro multisesión MM2/MM3/MM4.

**Criterio de aceptación:** el mismo objetivo y cable que funcionan con OTG
directo deben completar conexión, control, captura, grabación y transferencia a
través de cada USB-A de datos del ORICO homologado. Si Android no enumera el
objetivo en esa topología, la combinación queda marcada como incompatible con
evidencia diagnóstica, no como un falso éxito de software.

## Decisión sobre “migrar Kotlin a Flutter”

No se debe trasladar a Dart la lectura USB, el decoder, el muxer ni la escritura
de frames. Ese cambio no habilitaría iPhone y añadiría copias costosas de video
por `MethodChannel`.

La separación correcta es:

```text
Flutter/Dart
  - dominio y capacidades
  - ViewModel y UI
  - elección de adaptador
  - requisa/sesión
  - registro, cifrado, ledger y outbox

Adaptador nativo por transporte
  - descubrir/open/close del dispositivo
  - recibir y temporizar frames
  - renderizar preview nativo
  - capturar el último frame
  - codificar/remultiplexar grabación
  - escribir .part, fsync, rename y SHA-256
```

Se migra a Flutter la **orquestación y el contrato**, no el trabajo que depende
de AVFoundation, Camera2, libusb/libuvc, MediaCodec o MediaMuxer.

## Arquitectura objetivo

Se conserva la dirección obligatoria:

```text
LiveCaptureView
  -> LiveCaptureViewModel
    -> CaptureLiveFrame / StartLiveRecording / StopLiveRecording
      -> LiveVideoRepository
        -> LiveVideoRepositoryImpl
          -> VideoInputAdapter seleccionado por capacidades
            -> ScrcpyVideoInputPlatformService
            -> AndroidUvcVideoInputPlatformService
            -> IpadUvcVideoInputPlatformService
```

La transferencia de archivos permanece separada:

```text
FileTransferView -> FileTransferViewModel -> RemoteFileRepository
  -> AndroidAdbFilePlatformService | futuro IosAfcPlatformService
```

Esto evita que UVC herede operaciones de ADB y que la UI contenga condiciones
por sistema operativo.

### Contratos de dominio propuestos

Los modelos nuevos serán inmutables y Freezed. El propietario ejecutará los
generadores; no se editarán archivos generados manualmente.

```text
VideoTransport
  androidAdbScrcpy
  hdmiUvc

VideoInputCapabilities
  canPreview
  canControl
  canCaptureFrame
  canRecordVideo
  canCaptureAudio
  canReportTargetIdentity
  requiresUsbHost
  requiresCameraPermission

VideoInputDevice
  opaqueId
  displayName
  transport
  vendorId?
  productId?
  serialHash?
  formats[]
  capabilities

LiveVideoSession
  requisitionId
  sessionId
  transport
  inspectorPlatform
  targetPlatformDeclared
  device
  textureId/nativeViewId
  width
  height
  fps
  pixelFormat
  audioFormat?
  capabilities
```

`canReportTargetIdentity` será `false` para HDMI/UVC. La capturadora se
identifica a sí misma, pero no puede demostrar qué teléfono produce HDMI.

### Contratos Dart

```text
abstract interface class VideoInputAdapter
  availability()
  discoverInputs()
  requestPermission(inputId)
  open(requisitionId, sessionId, inputId, requestedFormat)
  activeSession(requisitionId, sessionId)
  captureFrame(requisitionId, sessionId)
  startRecording(requisitionId, sessionId)
  stopRecording(requisitionId, sessionId)
  close()
  events
```

El adaptador devuelve rutas y metadata; nunca buffers completos de video.

### Estructura prevista

```text
lib/domain/
├── models/live_video/
├── repositories/live_video_repository.dart
└── use_cases/acquisition/
    ├── connect_live_video.dart
    ├── capture_live_frame.dart
    ├── start_live_recording.dart
    └── stop_live_recording.dart

lib/data/
├── repositories/live_video_repository_impl.dart
└── services/platform/live_video/
    ├── scrcpy_video_input_platform_service.dart
    ├── android_uvc_video_input_platform_service.dart
    └── ipad_uvc_video_input_platform_service.dart

lib/ui/features/acquisition/
├── connect/
│   ├── view_models/
│   ├── views/
│   └── widgets/
└── live_capture/
    ├── view_models/
    ├── views/
    └── widgets/

android/app/src/main/kotlin/com/fiscalia/file_cast/acquisition/video/
├── LiveVideoPlugin.kt
├── LiveVideoSession.kt
├── scrcpy/ScrcpyVideoInput.kt
└── uvc/
    ├── AndroidUvcProbe.kt
    ├── Camera2UvcSession.kt
    ├── LibuvcSession.kt
    ├── UvcFrameCapture.kt
    └── UvcRecorder.kt

ios/Runner/Acquisition/Video/
├── LiveVideoPlugin.swift
├── IpadUvcProbe.swift
├── IpadUvcSession.swift
├── UvcFrameCapture.swift
└── UvcRecorder.swift
```

No se moverá el protocolo ADB/scrcpy estable durante la PoC. Primero se crea un
adaptador UVC aislado; la extracción del contrato común ocurre después de
demostrar video estable.

## Implementación en inspector Android

### Estrategia de apertura UVC

Se investigarán en este orden:

1. **Camera2 external camera:** enumerar `CameraManager.cameraIdList`, buscar
   `LENS_FACING_EXTERNAL` y verificar formatos/capacidades. Es el camino con API
   pública cuando el fabricante incluyó el external camera provider.
2. **libusb/libuvc embebido:** fallback para inspectores USB Host cuyo firmware no
   publica la capturadora en Camera2. Debe usar el file descriptor autorizado por
   `UsbManager`, sin root y sin daemon global.

No se puede asumir Camera2 solo porque el equipo tenga OTG. AOSP requiere soporte
de kernel y external camera provider del fabricante. La app debe publicar la
capacidad observada y la matriz debe fijar el camino usado en cada inspector.

### Preview

- Negociar primero 1080p30 SDR; degradar de forma visible a 720p30.
- Renderizar con `BoxFit.contain` y conservar barras; nunca estirar la señal.
- Publicar cambios de tamaño/formato y pérdida de señal al ViewModel.
- Mantener una cola acotada y descartar frames antiguos para priorizar baja
  latencia de preview.
- No interpretar gestos sobre la imagen como control del objetivo.

### Captura de frame

La captura UVC toma un frame completo posterior a la intención del operador:

```text
tap
  -> marcar sequence/timestamp mínimo
  -> esperar siguiente frame completo
  -> convertir en nativo a PNG o JPEG sin pasar pixels por MethodChannel
  -> escribir .part
  -> fsync + rename
  -> SHA-256
  -> devolver metadata
```

La evidencia se registra como `HDMI_UVC_FRAME_CAPTURE` y conserva resolución,
pixel format, timestamp del frame y cadena de hardware.

### Grabación

UVC puede entregar H.264, MJPEG o YUY2. La implementación debe elegir por modo:

- H.264 compatible: remultiplexar cuando timestamps/configuración sean válidos;
- MJPEG/YUY2: decodificar y codificar H.264/HEVC mediante MediaCodec;
- audio UAC: fuera de la primera fase; se añadirá con reloj y sincronización
  explícitos.

El grabador:

- inicia con un frame posterior al toque;
- escribe primero `.part`;
- usa timestamps monotónicos;
- finaliza de forma idempotente ante stop, detach, background o error;
- verifica pista, dimensiones y duración antes de registrar;
- calcula SHA-256 en nativo;
- elimina parciales inválidos.

`ScrcpyRecorder` no se reutiliza directamente: interpreta headers y PTS propios
de scrcpy. Se pueden extraer utilidades comunes de validación/atomicidad después
de tener pruebas, pero cada fuente conserva su parser y reloj.

### USB directo y OTG

- Separar receivers/sesiones ADB y UVC.
- En detach, cerrar solo la sesión cuyo `deviceId`/VID/PID/handle coincide.
- Enumerar interfaces UVC por descriptor, no solo clase global del dispositivo.
- Registrar permiso denegado, pérdida de señal, reset USB y cambio de formato.
- Medir consumo y autonomía con conexión directa; docking/PD queda fuera de esta
  versión.
- No iniciar UVC y ADB simultáneos hasta probar topologías y roles USB.

## Implementación en inspector Apple

### iPad Air 4 USB-C con iPadOS 27

La PoC usará AVFoundation:

```text
AVCaptureDevice.DiscoverySession(.external, .video, .unspecified)
  -> AVCaptureDeviceInput
    -> AVCaptureVideoDataOutput / preview
      -> captura de frame
      -> AVAssetWriter para grabación
```

Requisitos:

- iPad Air 4 del propietario con iPadOS 27 como equipo inicial de la matriz;
- mínimo de producto iPadOS 17 por la API UVC de AVFoundation, sujeto a la
  validación real y a la versión mínima de Flutter/iOS del proyecto;
- capturadora UGREEN conectada directamente por su USB-C integrado;
- `NSCameraUsageDescription` y, si se añade audio, `NSMicrophoneUsageDescription`;
- formato descubierto en runtime;
- manejo de connect/disconnect y `systemPressure`/interrupciones;
- archivo temporal privado, finalización, verificación y SHA-256 en Swift.

La PoC debe comparar dos previews:

- `AVCaptureVideoPreviewLayer` dentro de un PlatformView, con menor copia;
- `FlutterTexture` respaldada por `CVPixelBuffer`, si los overlays y composición
  lo requieren.

Se elegirá por latencia, consumo, estabilidad y capacidad de superponer los
controles Flutter sin glitches. La preview debe desactivar el mirroring
horizontal automático que AVFoundation aplica a cámaras externas tipo selfie,
porque aquí la fuente es una pantalla HDMI.

### iPhone inspector

No se implementará un adaptador UVC genérico que dependa de una capacidad no
publicada. El estado será `unsupported` y la UI explicará que el iPhone puede
seguir importando archivos locales, pero no actuar como monitor UVC.

Gate para reabrir el escenario:

1. Apple publica soporte UVC para iPhone mediante API pública; o
2. se adquiere un accesorio propietario compatible con iPhone que entregue SDK,
   licencia, App Store compliance y acceso programático documentado; y
3. una PoC demuestra preview, frame capture, recording y detach en la matriz.

Una app de terceros que muestre video no prueba que una app propia pueda usar la
misma ruta con una capturadora UVC genérica.

## Integración con evidencia y cadena de custodia

Cada sesión HDMI/UVC debe registrar:

```text
requisitionId
sessionId
operatorId
inspectorDeviceId / OS / app build
targetPlatformDeclared
targetDeviceInventoryId declarado por el operador
transport = HDMI_UVC
captureCardInventoryId
captureCard VID/PID/serial hash
captureCard firmware si está disponible
videoAdapterInventoryId
HDMI cable inventoryId
otgAdapterInventoryId si aplica
negotiated resolution/fps/pixel format/color range
audio format si aplica
signal connected/lost timestamps
recording start/stop monotonic timestamps
native adapter version/hash
```

La UI debe exigir confirmar el objetivo y accesorios porque HDMI no transporta
una identidad confiable del teléfono fuente.

El pipeline común continúa:

```text
archivo plano nativo validado
  -> EvidenceRepository
    -> cifrado FCE
      -> eliminar plano
        -> SQLite SQLCipher + outbox
          -> sincronización
```

El ledger inmutable sigue siendo deuda transversal y no debe declararse resuelto
por esta feature.

## Navegación y UX

### Rutas

Conservar IDs de negocio en path:

```text
# Mirror Android existente
/requisitions/:requisitionId/acquisitions/:sessionId/connect
/requisitions/:requisitionId/acquisitions/:sessionId/mirror

# Transferencia existente
/requisitions/:requisitionId/acquisitions/:sessionId/connect?destination=transfer
/requisitions/:requisitionId/acquisitions/:sessionId/transfer

# Capturadora nueva y explícita
/requisitions/:requisitionId/acquisitions/:sessionId/capture-card/connect
/requisitions/:requisitionId/acquisitions/:sessionId/capture-card/live
```

Capturadora usa rutas propias para conservar las cuatro acciones del producto y
no reinterpretar Mirror como un selector de transportes. El handle de textura o
native view es efímero y viaja en argumentos tipados; si falta, la ruta muestra
fallback y permite reconectar. El ViewModel no recibe `BuildContext` ni navega.

Las rutas actuales de Mirror y Transferencia se conservan. Importar archivos
continúa como selector/preview desde el detalle y no necesita una ruta de sesión
de hardware antes de confirmar.

### Launcher de cuatro opciones

- Android: las cuatro tarjetas activas según dispositivo/permisos.
- iPad: Capturadora e Importar activas; Mirror y Transferencia visibles con
  explicación de plataforma no disponible.
- La selección de Capturadora crea/reutiliza una sesión `HDMI_UVC` y navega a su
  conexión específica.
- La disponibilidad se obtiene del ViewModel y repositorios, no de condiciones
  profundas en widgets.

### Acciones por capacidades

| Capacidad | ADB/scrcpy | HDMI/UVC |
|---|---:|---:|
| Preview | Sí | Sí |
| Captura | `screencap` | Siguiente frame UVC |
| Grabación | Remux H.264 | Remux o encode de UVC |
| Tap/drag/keys | Sí | Oculto |
| Back/Home/Recent | Sí | Oculto |
| Browser de archivos | Sí, ruta separada | Oculto |
| Diagnóstico | ADB/scrcpy | señal, formato, FPS, drops, USB |

No se mostrarán controles deshabilitados que sugieran que HDMI puede controlar
el objetivo.

### Responsive

- Compact `<600`: preview como contenido principal, controles abajo y tira de
  evidencias horizontal sin cubrir la señal.
- Medium `600..839`: preview con panel de estado plegable.
- Expanded `840..1199` y large `>=1200`: preview y evidencias en dos paneles,
  conservando ancho legible.
- Altura `<480`: priorizar preview y controles esenciales; diagnóstico en hoja.
- Decidir por `LayoutBuilder`/constraints, no por orientación ni tipo físico.
- Respetar SafeArea, text scaling, teclado, mouse y targets de 48 dp.
- Preservar tema, iconografía y composición actual del mirror; UVC no autoriza un
  rediseño de identidad.

## Fases de implementación

### Fase 0 — inventario y ADR de transporte

- ejecutar el gate ORICO de un solo Android: comparar `UsbManager.deviceList`,
  interfaces y endpoints en conexión directa versus a través del hub;
- implementar/planificar clasificación ADB exacta y errores de enumeración antes
  de atribuir el fallo al handshake;
- registrar VID/PID, nombre USB y serial/firmware disponible de la UGREEN
  fotografiada;
- confirmar HDMI IN, USB-C/USB-A data y ausencia de loop-out;
- registrar cables, OTG y adaptadores con ID de inventario;
- obtener descriptores UVC/UAC y modos reales en un host de laboratorio;
- seleccionar inspectores Android candidatos;
- registrar iPad Air 4/iPadOS 27 como inspector Apple inicial;
- ADR: Camera2-only vs Camera2 + libuvc;
- revisar licencia/SBOM de libusb/libuvc o biblioteca elegida.

**Salida:** matriz de hardware exacta, dictamen reproducible del ORICO con un
solo objetivo ADB y demo que detecta la capturadora sin abrir video.

### Fase 1 — contrato común y capabilities

- definir las cuatro acciones `mirror`, `fileTransfer`, `captureCard` e
  `importFiles` con capacidades independientes;
- crear modelos Freezed de transporte, dispositivo, formato, capacidades y
  sesión;
- separar video en vivo de transferencia remota;
- adaptar scrcpy detrás de `VideoInputAdapter` sin reescribir protocolo;
- reemplazar capacidades derivadas de `ANDROID` por capacidades observadas;
- registrar dependencias con `provider`;
- definir errores tipados.

**Salida:** el flujo actual Android ADB conserva comportamiento mediante el nuevo
contrato.

### Fase 2 — spike UVC Android

- enumerar Camera2 external y descriptors USB;
- solicitar permisos correctos;
- abrir 720p30 y 1080p30;
- renderizar preview 30 minutos;
- medir latencia, drops, CPU, temperatura y consumo;
- probar detach/reconnect 20 veces;
- implementar fallback libuvc únicamente si la matriz lo exige.

**Salida:** decisión de adapter Android y una capturadora homologable.

### Fase 3 — captura y grabación UVC Android

- captura del siguiente frame posterior al tap;
- recorder por formato de entrada;
- `.part`, fsync, rename, validación y SHA-256;
- progreso/estado y cleanup idempotente;
- metadata de hardware y señal;
- integración con FCE/outbox existente.

**Salida:** PNG/JPEG y MP4 reproducibles, ligados a requisa/sesión y con método
HDMI/UVC explícito.

### Fase 4 — Capturadora en iPad Air 4

- implementar plugin Swift con AVFoundation;
- descubrir exclusivamente `AVCaptureDevice.DeviceType.external`;
- seleccionar la capturadora UGREEN y sus formatos reales;
- preview sin mirroring horizontal;
- capturar el siguiente frame posterior al toque;
- grabar/finalizar con AVAssetWriter o salida equivalente validada;
- `.part`, fsync/atomic replace, validación y SHA-256;
- manejar connect/disconnect, interrupciones y background;
- integrar FCE/outbox mediante el mismo repositorio Dart;
- comparar PlatformView y FlutterTexture y documentar la decisión.

**Salida:** Capturadora muestra, captura y graba la misma señal en iPad Air 4,
ligada a requisa/sesión.

### Fase 5 — launcher, workspace y navegación

- launcher con las cuatro opciones y disponibilidad explicada;
- rutas `capture-card/connect` y `capture-card/live` separadas de Mirror;
- workspace común de Capturadora para Android/iPad;
- ocultar control y transferencia en UVC;
- estados `loading`, `noSignal`, `content`, `detached`, `unsupported`, `error`;
- fallback restaurable y responsive.

**Salida:** operador distingue Mirror, Transferencia, Capturadora e Importar sin
confundir sus transportes o alcances.

### Fase 6 — audio opcional

- descubrir interfaz UAC;
- negociar formato;
- sincronizar relojes A/V;
- registrar pérdida de audio y drift;
- permitir video sin audio como degradación visible.

**Salida:** grabación A/V solamente en combinaciones homologadas.

### Fase 7 — hardening y validación

- pérdida/recuperación de señal HDMI;
- cambio de resolución y rotación del target;
- background/foreground, poca batería y poco espacio;
- desconexión durante grabación;
- 60 minutos de preview y 30 minutos de grabación;
- 100 capturas comparadas;
- calibración de color, escala, barras y latencia;
- revisión de HDCP/DRM y contenido negro;
- manifiesto de hardware, logs redactados y cadena de custodia;
- validación jurídica/forense y manual operativo.

**Salida:** piloto limitado a combinaciones exactas aprobadas.

### Fase 8 obligatoria de producto — hub USB y N entradas

Esta fase no bloquea el primer piloto de Capturadora, pero sí forma parte del
alcance final de File Cast. Su ejecución detallada está en
[ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md](ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md)
y progresa obligatoriamente de un mirror a dos y finalmente a tres.
Después elimina el límite fijo y valida 4/5/6 con un hub alimentado de seis
puertos.

- registrar modelo impreso, ASIN `B0BYS4D3KR`, chipset si está disponible,
  puertos de datos, PD, firmware y topología real del ORICO;
- partir del caso obligatorio ya aprobado de un solo Android ADB y validar una
  sola capturadora UVC a través del hub;
- clasificar dispositivos por interfaces ADB, UVC/UAC, HID, almacenamiento y
  hub; no ofrecer HID o el propio hub como objetivo;
- reemplazar los singletons nativos por un registro de sesiones indexado por
  `deviceId`/handle, cada una con conexión, transporte, streams, decoder,
  recorder, textura, requisa y sesión propios;
- hacer que attach/detach, permisos, errores y cleanup afecten solo al handle
  correspondiente;
- limitar concurrencia según decoders H.264 disponibles, memoria, temperatura,
  ancho de banda USB y energía observada;
- definir si el producto permite varias fuentes dentro de una misma sesión de
  adquisición o exige una sesión por objetivo;
- crear un workspace multivista separado; no convertir silenciosamente el
  Mirror actual en una cuadrícula;
- validar escalonadamente 1, 2 y 3 mirrors durante 60 minutos, con control,
  captura, grabación, detach individual y reconexión.

**Salida:** multisesión dinámica hasta `maxConcurrentMirrors`, con ORICO
homologado para tres y una matriz ampliada homologada para seis. Si un inspector
no sostiene la cantidad requerida, se reduce perfil o se sustituye por uno
homologable. El hub por sí solo no aporta esa capacidad al software.

## Errores mínimos

```text
uvcUnsupportedInspector
uvcDeviceNotFound
uvcPermissionDenied
uvcFormatUnsupported
uvcSignalMissing
uvcSignalProtected
uvcBandwidthInsufficient
uvcPowerInsufficient
uvcDeviceDetached
uvcFrameTimeout
uvcRecordingAlreadyActive
uvcRecordingStartTimeout
uvcRecordingFinalizeFailed
uvcInsufficientStorage
uvcSourceChanged
```

Los códigos no incluirán nombres de personas, CUD, rutas sensibles ni contenido
de evidencia.

## Matriz mínima de validación física

### Inspectores

- Android compacto homologado con USB-C/OTG;
- Android tablet homologada;
- un Android cuyo firmware exponga Camera2 external;
- un Android que requiera fallback libuvc, solo si se decide soportarlo;
- iPad Air 4 USB-C con iPadOS 27 como inspector obligatorio;
- iPhone fuera de la compilación/validación de inspector de esta etapa.

### Objetivos

- iPhone Lightning + Apple Digital AV Adapter;
- iPhone USB-C + USB-C -> HDMI;
- Android USB-C con DP Alt Mode;
- Android USB-C sin salida de video, para validar mensaje de incompatibilidad;
- Android Micro-USB solo si se adquiere el adaptador MHL/SlimPort correcto.

### Capturadoras y topologías

- UGREEN fotografiada y enlazada por el propietario;
- conexión USB-C directa a Android;
- conexión USB-C directa a iPad Air 4;
- variante USB-A integrada + OTG solo si Android no negocia host por USB-C;
- 720p30, 1080p30 y 1080p60 cuando esté anunciado;
- 2K30 como prueba posterior, no baseline;
- audio desactivado y, en fase posterior, UAC activo.

Para cada combinación registrar:

1. inventario completo y versiones;
2. descriptors y formato negociado;
3. 20 ciclos attach/detach;
4. tiempo hasta primer frame;
5. latencia extremo a extremo;
6. FPS observados y frames descartados;
7. 60 minutos de preview;
8. 100 capturas con hash y revisión visual;
9. grabación de 1, 5 y 30 minutos;
10. desconexión y pérdida de señal durante grabación;
11. tamaño, duración, pista, codec y reproducción del MP4;
12. temperatura, consumo y throttling;
13. diferencias de color, crop, barras, rotación y audio;
14. comportamiento con contenido protegido;
15. resultado repetible.

## Gates de decisión

No se avanza si falla alguno de estos gates:

1. **Enumeración:** la capturadora se identifica sin root y con permisos claros.
2. **Señal:** 1080p30 o el baseline aprobado permanece estable 60 minutos.
3. **Integridad:** frame y grabación se finalizan atómicamente y verifican hash.
4. **Lifecycle:** detach/background no dejan handles, textura o `.part` huérfanos.
5. **Evidencia:** requisa, sesión, operador, método y hardware quedan registrados.
6. **Semántica:** la UI distingue captura HDMI/UVC de screenshot nativo.
7. **Licencia:** dependencias nativas, avisos y SBOM están aprobados.
8. **Matriz:** la combinación exacta de inspector Android/iPad Air 4,
   capturadora, adaptador, target y OS está homologada.

El escenario iPhone inspector tiene un gate adicional: una API pública de Apple
o un SDK de accesorio aprobado. Mientras no exista, permanece fuera de alcance.

## Riesgos principales

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Android OTG no implica Camera2 external | Capturadora visible por USB pero no como cámara | Probe Camera2 + spike libuvc; homologar inspectores |
| iPhone no admite UVC genérico como inspector | No puede ser inspector de Capturadora | Compilar para Android/iPad Air 4; iPhone fuera de esta etapa |
| Android objetivo no ofrece DP Alt Mode | No existe señal HDMI | Mantener ADB/scrcpy o adquirir adaptador específico si el modelo soporta MHL/SlimPort |
| Marketing confunde passthrough con captura | Resolución/FPS inferiores | Leer descriptors y mostrar modo negociado |
| HDCP/DRM | Pantalla negra o señal rechazada | Declarar límite; no intentar bypass |
| Conexión directa consume batería | Sesión limitada por autonomía | Medir batería/temperatura y fijar duración operativa; docking queda para una fase posterior |
| HDMI no identifica al target | Metadata de fuente no verificable automáticamente | Identificación operativa y fotos/inventario de la cadena |
| UVC entrega MJPEG/YUY2 | CPU/temperatura altos al grabar | MediaCodec, baseline 1080p30 y soak tests |
| Audio usa reloj distinto | Desincronización A/V | Fase separada con timestamp/drift explícitos |
| Detach global rompe ADB | Sesión incorrecta cerrada | Sesiones por handle/deviceId y receivers separados |
| Hub enumera HID y hub junto a teléfonos | El operador selecciona un periférico sin ADB | Probe de interfaces y filtro por capacidades antes de mostrar candidatos |
| N mirrors comparten recursos | Saturación USB, falta de decoders, calor o cierres | `maxConcurrentMirrors`, calidad adaptativa y homologación progresiva 1..N |

## Criterio de finalización

La captura HDMI/UVC estará lista para piloto cuando:

- un inspector Android homologado abra una capturadora aprobada sin root;
- el iPad Air 4 con iPadOS 27 descubra la misma capturadora mediante AVFoundation;
- iPhone Lightning, iPhone USB-C y al menos un Android con salida HDMI superen la
  matriz con ambos inspectores requeridos donde aplique;
- preview, captura y grabación sobrevivan a la prueba de duración y lifecycle;
- cada archivo se valide, hashee, cifre y registre contra requisa/sesión;
- la UI no ofrezca control ni transferencia donde UVC no los provee;
- la metadata describa la cadena completa y el método `HDMI_UVC`;
- los límites de HDCP, salida de video y procedencia estén visibles;
- licencias, SBOM y procedimiento operativo estén aprobados;
- el piloto se limite a combinaciones exactas validadas.

Además, el launcher debe conservar las cuatro opciones como contratos separados:
Mirror, Transferencia, Capturadora e Importar archivos.

El soporte de iPhone como inspector **no forma parte de este criterio** mientras
Apple no exponga UVC genérico en iPhone o no exista un accesorio/SDK específico
aprobado.

## Fuentes técnicas verificadas

- [AOSP — External USB cameras](https://source.android.com/docs/core/camera/external-usb-cameras)
- [Android — Camera lenses and capabilities](https://developer.android.com/media/camera/camera2/camera-enumeration)
- [Apple — `AVCaptureDevice.DeviceType.external`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct/external)
- [Apple WWDC23 — Support external cameras in your iPadOS app](https://developer.apple.com/videos/play/wwdc2023/10106/)
- [Apple Developer Forums — UVC support is implemented only on iPads with USB 3](https://developer.apple.com/forums/thread/776912)
- [Apple — Charge and connect with USB-C on iPhone](https://support.apple.com/105099)
- [Apple — Lightning Digital AV Adapter](https://www.apple.com/shop/product/mw2p3am/a/lightning-digital-av-adapter)
- [Apple — iPad Air 4 technical specifications](https://support.apple.com/111905)
- [Apple — USB-C on iPad](https://support.apple.com/108894)
- [UGREEN Bolivia — capturadora aportada: input 4K30, capture 2K30/1080p60, iPadOS 17+](https://www.ugreen-bo.com/products/ugreen-captura-de-video-hdmi-4k-30hz-a-usb-a-c-30-2k-30hz-1080p)
- [libuvc official repository](https://github.com/libuvc/libuvc)
- [libusb Android notes](https://github.com/libusb/libusb/tree/master/android)
- [Android Developers — USB host y enumeración de dispositivos](https://developer.android.com/develop/connectivity/usb/host)
- [ORICO aportado por el propietario — ASIN B0BYS4D3KR](https://www.amazon.com.be/-/en/ORICO-Ethernet-Docking-Station-Multiport/dp/B0BYS4D3KR)
