# Plan de implementación de Mirror múltiple mediante hub USB

Fecha: 16 de noviembre de 2026

Última revisión: 19 de noviembre de 2026

Estado: **vertical ADB multisesión funcional con dos fuentes según pruebas del
propietario; pendiente soak/homologación de tres a N y extensión HDMI/UVC
mixta**

Hardware inicial: hub/docking ORICO enlazado por el propietario, ASIN
`B0BYS4D3KR`, conectado por USB-C al Android inspector y con tres puertos USB-A
downstream para objetivos Android.

Este documento define cómo conservar el Mirror/control actual y ampliarlo de
forma progresiva para:

1. un Android objetivo mediante el ORICO;
2. dos Android objetivo con mirrors y controles independientes;
3. tres Android objetivo con mirrors y controles independientes.

La arquitectura no tendrá un máximo fijo de tres. El ORICO define la primera
matriz 1/2/3 porque posee tres USB-A; un hub alimentado de seis puertos debe
poder solicitar 4/5/6 mirrors sin reescribir el plugin, sujeto a la capacidad
real del inspector y a una homologación separada.

La siguiente ampliación no crea otra multisesión: el mismo selector y workspace
deben aceptar fuentes `androidAdbScrcpy` y `hdmiUvc`. El escenario de aceptación
principal será dos Android ADB y una capturadora UGREEN conectados al ORICO.

Debe leerse junto con:

- [PROJECT_STATUS_AND_FEASIBILITY.md](PROJECT_STATUS_AND_FEASIBILITY.md);
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md);
- [HARDWARE_REQUIREMENTS.md](HARDWARE_REQUIREMENTS.md);
- [ADB_HANDSHAKE.md](ADB_HANDSHAKE.md);
- [HDMI_UVC_VIDEO_CAPTURE_IMPLEMENTATION_PLAN.md](HDMI_UVC_VIDEO_CAPTURE_IMPLEMENTATION_PLAN.md);
- [HDMI_UVC_CABLE_CONNECTION_GUIDE.md](HDMI_UVC_CABLE_CONNECTION_GUIDE.md);
- `AGENTS.md` y las skills Flutter del repositorio.

> Límite de ejecución: este plan no autoriza tests, analyze, run, builds nativos
> ni generadores. La validación física queda a cargo del propietario cuando se
> implemente cada fase.

## Dictamen

El ORICO puede funcionar como un **hub OTG multipuerto** para File Cast cuando:

- el USB-C upstream está conectado al inspector;
- el inspector negocia y conserva el rol USB Host;
- cada USB-A usado es un puerto de datos downstream;
- cada cable USB-A -> USB-C transporta datos;
- cada objetivo expone la interfaz ADB y autoriza la clave RSA;
- la energía del hub/inspector alcanza para mantener todos los enlaces.

Que un objetivo cargue demuestra VBUS, no demuestra datos. Que mouse y teclado
funcionen demuestra rol host y funcionamiento HID, pero no prueba que un
teléfono concreto haya enumerado ADB.

Android permite enumerar varios `UsbDevice` conectados al bus. Sin embargo,
La primera vertical multi ya registra sesiones independientes por
`sourceSessionId`. La validación física sigue pendiente: el propietario debe
aprobar primero M1, luego M2 y M3, y finalmente la matriz N del hub ampliado.

La meta de producto queda fijada así:

| Etapa | Objetivos conectados | Mirrors activos | Control | Estado actual | Gate |
|---|---:|---:|---:|---|---|
| M1 | 1 | 1 | Independiente | Funcional en pruebas del propietario | Repetibilidad por cada puerto |
| M2 | 2 | 2 | Independiente por mirror | Funcional con USB-C/Micro-USB; falta soak | Dos sesiones 60 min sin cierre |
| M3 | 3 | 3 | Independiente por mirror | Código listo; pendiente laboratorio | Recursos, energía y estabilidad |
| MN | 4–N | Hasta `maxConcurrentSources` | Una fuente enfocada a la vez | Registro dinámico listo; pendiente hub ampliado | Capacidad homologada |

La implementación no salta etapas: M2 no comienza hasta aprobar M1 y M3 no
comienza hasta aprobar M2.

## Principio de diseño: N fuentes de video, no tres hardcodeadas

El software no usará campos `deviceA/deviceB/deviceC`, tres variables de
conexión ni una lista con longitud fija. El contrato será una colección
dinámica indexada por `sourceSessionId`.

```text
enumeratedVideoSourceCount
requestedSourceCount
maxConcurrentSources
activeSourceCount
sources: Map<sourceSessionId, LiveVideoSourceSession>
```

`maxConcurrentSources` es una capacidad calculada, no una constante universal.
Es el mínimo entre:

- fuentes ADB/UVC enumeradas y autorizadas;
- límite operativo configurado para la matriz homologada;
- conexiones USB estables observadas;
- decoders H.264 concurrentes que el inspector puede sostener;
- presupuesto de memoria, temperatura, energía y ancho de banda;
- política de grabaciones simultáneas.

| Hardware conectado | Fuentes enumeradas | Capacidad homologada del inspector | Fuentes ofrecidas |
|---|---:|---:|---:|
| ORICO de 3 puertos | 3 | 3 | 3 |
| Hub de 6 puertos | 6 | 3 | 3, con explicación de capacidad |
| Hub de 6 puertos | 6 | 6 | 6 |
| Hub de 6 puertos | 4 | 6 | 4 |

El nombre `maxConcurrentMirrors` puede conservarse transitoriamente en APIs
existentes durante la migración, pero no debe propagarse a contratos nuevos.
El objetivo de arquitectura es permitir N. La compatibilidad operativa se
declara por combinación exacta de inspector, hub, cargador, cables, objetivos y
perfil de video.

## Topología física objetivo

```text
Cargador USB-C PD homologado
  -> PD IN del ORICO

Android inspector USB-C, rol host
  -> USB-C upstream del ORICO
     |-> USB-A datos #1 -> cable de datos -> Android objetivo A
     |-> USB-A datos #2 -> cable de datos -> Android objetivo B
     `-> USB-A datos #3 -> cable de datos -> Android objetivo C
```

El HDMI del ORICO es salida del inspector y no participa en Mirror ADB. El
puerto PD es entrada de energía y no sustituye un puerto USB de datos.

Para M1 se conecta solamente el objetivo A. Para M2 se agregan A y B. Para M3
se usan A, B y C. Mouse, teclado, Ethernet, memorias y capturadora permanecen
desconectados durante la caracterización inicial.

### Topología mixta obligatoria después de caracterizar ADB y UVC directo

```text
Cargador USB-C PD homologado -> PD IN del ORICO

Android inspector USB-C, rol host
  -> USB-C upstream del ORICO
     |-> USB-A #1 -> Android A -> ADB/scrcpy
     |-> USB-A #2 -> Android B -> ADB/scrcpy
     `-> USB-A #3 -> adaptador USB-A de UGREEN -> UVC
                       <- HDMI <- adaptador de video <- objetivo C
```

El inventario debe publicar tres fuentes seleccionables, no “dos teléfonos y
un periférico desconocido”. El teléfono detrás de HDMI no se identifica por
USB; File Cast identifica la capturadora y solicita/recupera una etiqueta
declarada para el objetivo conectado a ella.

## Hallazgos del código actual

El flujo funcional sigue concentrando el bridge en
`android/app/src/main/kotlin/com/fiscalia/file_cast/usb/UsbPlugin.kt`, pero la
vertical multi ya añadió un registro source-scoped:

- los métodos `multi*` mantienen ADB, shell scrcpy, sockets, textura, decoder,
  control y recorder por `sourceSessionId`;
- `AndroidAcquisitionPlatformService` conserva `_activeSession` para
  compatibilidad singular y `_multiSessions` para la colección;
- `getConnectedDevices()` publica clasificación diagnóstica
  (`android_adb`, `mtp`, `hub`, `hid`, `video`, `other`) y la interfaz exacta
  `255/66/1` decide si una fuente ADB es seleccionable;
- captura, grabación, reload y control multi ya reciben la fuente concreta;
- los argumentos y ViewModels multi todavía suponen que toda fuente es ADB y
  controlable;
- no existe aún un adaptador UVC que publique formato, señal, textura y recorder
  propios.

Por tanto, el trabajo pendiente no es volver a enumerar ADB ni crear otra
grilla. Debe generalizarse el modelo de fuente/capacidades y agregar UVC sin
reescribir el protocolo ADB ya funcional.

El protocolo ADB y scrcpy dentro de cada conexión ya funcionan y se conservan.
El cambio necesario es de **propiedad y ciclo de vida por dispositivo**, no una
reescritura del protocolo.

## Implementación ADB entregada

- `UsbPlugin.kt` conserva las APIs singulares y añade métodos `multi*` con un
  estado nativo por fuente: ADB, shell scrcpy, sockets, textura, decoder,
  control, captura y grabación.
- `UsbAdbTransport.kt` ya no reclama una interfaz arbitraria: exige la interfaz
  ADB exacta `255/66/1`, evitando seleccionar el hub, HID o UVC.
- `getConnectedDevices` publica `hasAdbInterface`, `deviceType` e inventario de
  interfaces. Flutter conserva todos para diagnóstico visual y habilita Mirror
  únicamente en candidatos ADB.
- Cada tarjeta muestra serial USB abreviado cuando Android lo permite y la
  dirección bus/device (`USB 001/004`) para diferenciar descriptores genéricos
  como `SAMSUNG SAMSUNG_Android`. La API pública `UsbDevice` no publica el
  número físico del puerto downstream del hub; la dirección diferencia la
  conexión actual, pero puede cambiar al reconectar.
- La lectura de `serialNumber` y descriptores USB es defensiva: Android 10+
  puede lanzar `SecurityException` antes del permiso. Un descriptor protegido
  ya no convierte toda la enumeración del hub en una lista vacía.
- `android.hardware.usb.host` se conserva como hint del fabricante, pero no
  bloquea la pantalla: algunos OEM lo omiten aunque `UsbManager` enumere MTP o
  ADB. La lista real de `UsbDevice` es la evidencia operativa.
- La capa Dart añade `connectAndStartMulti`, control por fuente, captura y
  grabación enfocadas, manteniendo el flujo singular intacto.
- La identidad ADB RSA es única y persistente para todo File Cast. Singular y
  multi firman con el mismo par, y multi reintenta después de la reenumeración
  que algunos Samsung realizan al aceptar la clave por primera vez.
- La navegación añade la variante `/mirrors/live`, selección múltiple de
  objetivos y un workspace con modo simultáneo 1/2/3 columnas y modo enfocado
  con selector de fuente. No existe un límite de tres en la colección; la
  capacidad real sigue siendo un gate físico.

## Gate previo: resolver el primer objetivo USB-C que queda en MTP sin ADB

Antes de crear multisesión se debe obtener un snapshot diagnóstico para la misma
combinación inspector + ORICO + cable + objetivo.

### Gate 1 — enumeración del sistema

Registrar antes y después de conectar el objetivo:

```text
deviceName
vendorId/productId
manufacturer/product/serial cuando sean accesibles
device class/subclass/protocol
interface count
class/subclass/protocol de cada interfaz
endpoints, dirección y tipo
permiso USB
timestamp attach/detach
```

Resultado:

- si no aparece un nuevo `UsbDevice`, el fallo es cable/puerto/rol/energía o
  firmware de la combinación; la app no puede crear una conexión inexistente;
- si aparece pero no contiene `255/66/1`, el objetivo no está exponiendo ADB;
- si contiene `255/66/1`, el fallo posterior es corregible en File Cast.

Si el inspector puede abrir la galería/archivos del objetivo, el sistema ya
enumeró MTP y el inspector está ejerciendo el rol host. En ese caso no se debe
diagnosticar `host inactivo`: corresponde `MTP sin ADB`. Se debe activar
Depuración USB en el objetivo, mantenerlo desbloqueado, reconectar y aceptar la
huella RSA. File Cast no puede activar ADB ni forzar el rol USB-C de otro equipo
mediante APIs públicas.

### Gate 2 — selección y permiso

- clasificar dispositivos por sus interfaces;
- exponer a Mirror solo candidatos `adb`;
- mostrar hub, MTP, HID, almacenamiento o UVC como diagnóstico no seleccionable,
  sin presentarlos como Android objetivo apto para Mirror;
- pedir permiso para el `deviceId`/`deviceName` seleccionado;
- eliminar el fallback operativo a la primera interfaz no ADB;
- diferenciar `notEnumerated`, `noAdbInterface`, `permissionDenied`,
  `claimFailed`, `handshakeFailed` y `reenumerating`.

### Gate 3 — equivalencia con OTG directo

Con el mismo objetivo y cable:

1. aprobar conexión directa/OTG;
2. aprobar conexión mediante USB-A #1;
3. repetir en USB-A #2;
4. repetir en USB-A #3;
5. conectar PD y repetir sin perder el rol host.

M1 se aprueba solamente cuando Mirror, control, captura, grabación y
Transferencia funcionan de forma repetible a través del ORICO.

## Arquitectura objetivo

Se mantiene la dirección obligatoria:

```text
MultiMirrorView
  -> MultiMirrorViewModel
    -> StartMirrorSources / StopMirrorSource / SelectControlledSource
      -> MultiMirrorRepository
        -> MultiMirrorRepositoryImpl
          -> AndroidMultiAdbPlatformService
            -> AdbDeviceSessionRegistry
              -> AdbDeviceSession A
              -> AdbDeviceSession B
              -> AdbDeviceSession C
```

Mirror singular existente puede usar el mismo registro con un solo elemento,
sin cambiar su comportamiento visible.

### Registro nativo de sesiones

Reemplazar los singletons de conexión por:

```text
AdbDeviceSessionRegistry
  sessions: Map<sourceSessionId, AdbDeviceSession>

AdbDeviceSession
  sourceSessionId
  usbDeviceName/deviceId
  UsbDeviceConnection
  UsbAdbTransport
  handshake state/generation
  scrcpy shell/video/control stream IDs
  SurfaceTextureEntry
  ScrcpyDecoder
  ScrcpyRecorder
  video width/height
  selected/controlled state
  requisitionId/acquisitionSessionId
```

`AdbAuth` puede compartir la identidad RSA institucional del inspector, pero
cada transporte, stream, decoder, textura, recorder y cleanup pertenece a una
sesión fuente.

Todas las llamadas nativas sensibles deben recibir `sourceSessionId`:

```text
connectAdb(sourceSessionId, deviceId)
startScrcpy(sourceSessionId)
sendTouch(sourceSessionId, ...)
sendKey(sourceSessionId, ...)
captureScreenshot(sourceSessionId, requisitionId, sessionId)
startRecording(sourceSessionId, requisitionId, sessionId)
stopRecording(sourceSessionId)
disconnect(sourceSessionId)
```

No se reutilizará un `localId` de ADB entre transportes. Los IDs de stream son
locales a cada `UsbAdbTransport`.

### Attach, detach y reenumeración

- attach actualiza el inventario y solo despierta la operación pendiente del
  mismo dispositivo;
- detach busca la sesión por `deviceId` y cierra exclusivamente esa fuente;
- retirar una fuente no detiene ninguna de las restantes;
- una reenumeración durante RSA conserva la intención de B sin vincular por
  error otro teléfono;
- el cierre de una fuente finaliza/aborta solamente su recorder y su `.part`;
- salir del workspace cierra todas las fuentes activas de forma idempotente.

### Contratos de dominio

Los modelos nuevos serán Freezed y no dependerán de Flutter:

```text
MirrorSource
  sourceSessionId
  acquisitionSessionId
  usbDeviceId
  displayName/slotLabel
  vendorId/productId
  connectionPhase
  textureId?
  videoWidth/videoHeight
  canControl/canCapture/canRecord/canTransfer
  isControlled
  recordingPhase
  diagnostics

MultiMirrorSession
  requisitionId
  sessionId
  requestedSourceCount
  maxConcurrentSources
  sources[]
  focusedSourceSessionId
  startedAtUtc
  status
```

La identidad probatoria de cada evidencia incluye la fuente concreta:

```text
requisitionId
acquisitionSessionId
sourceSessionId
sourceDeviceId/serialHash cuando esté disponible
slotLabel
acquisitionMethod
```

Una captura de A no puede quedar registrada como si proviniera de B o C.

### Extensión obligatoria a fuentes mixtas

Antes de registrar UVC, `MirrorSource` debe evolucionar sin depender de Flutter
a un contrato equivalente a:

```text
LiveVideoSource
  sourceSessionId
  acquisitionSessionId
  inputDeviceId
  displayName/slotLabel
  transport: androidAdbScrcpy | hdmiUvc
  capabilities
  textureId/nativeViewId?
  videoWidth/videoHeight/fps/format
  targetIdentityKind: reported | operatorDeclared
  controlStreamId?
  status/diagnostics

LiveVideoCapabilities
  canPreview
  canControl
  canCaptureFrame
  canRecordVideo
  canReload
  canTransfer
  canReportTargetIdentity
```

El registro ADB nativo y el registro UVC nativo permanecen separados. Un
repositorio Dart agrega ambos inventarios y conserva la relación
`sourceSessionId -> adapter`. Así `sendTouch` solo existe para ADB, mientras
`captureFrame`, `startRecording`, `stopRecording`, `reload` y `close` se
despachan al adaptador correspondiente.

La UI no pregunta “¿es Android?”: consulta capacidades. El selector muestra
badges **Mirror + control · ADB/scrcpy** y **Capturadora · HDMI/UVC · sin
control**. Una celda sin control sigue siendo seleccionable y participa en
captura, grabación, evidencias, diagnóstico y lifecycle.

## Orquestación de conexiones

Para reducir fallos durante la primera implementación:

1. enumerar N candidatos ADB;
2. calcular `maxConcurrentSources` y permitir seleccionar hasta ese límite;
3. asignar slots/alias estables por orden de selección;
4. solicitar permisos de forma secuencial;
5. completar handshake y scrcpy de cada fuente sin detener las anteriores;
6. publicar cada fuente apenas esté lista;
7. permitir reintentar solo la fuente fallida;
8. rechazar una fuente adicional con un motivo visible cuando se alcance el
   límite homologado, sin cerrar las ya activas.

El ViewModel controla concurrencia e idempotencia. La View solo muestra estado
y emite intenciones.

## Control, captura y grabación

### Control

- solo un mirror recibe teclado/mouse/touch a la vez;
- tocar o enfocar una tarjeta la convierte en fuente controlada;
- la tarjeta activa muestra un borde/etiqueta inequívoca;
- los eventos incluyen siempre `sourceSessionId`;
- cambiar el foco no reinicia ningún stream;
- Back/Home/Recent se envían solamente a la fuente activa.

### Captura

- cada tarjeta tiene acción Capturar;
- `screencap -p` se abre en el transporte de esa fuente;
- archivo, hash y metadata incluyen `sourceSessionId`;
- se permite una captura por fuente simultánea si el registro y almacenamiento
  soportan la concurrencia; la primera versión puede serializar escrituras sin
  detener previews.

### Grabación

- cada fuente tiene `ScrcpyRecorder` propio;
- iniciar/grabar/detener una fuente no cambia las demás;
- se valida primero una grabación activa total;
- luego dos grabaciones concurrentes;
- tres grabaciones concurrentes solo se habilitan si CPU, almacenamiento,
  temperatura y decoders/encoders permanecen dentro de umbrales homologados;
- para 4–6 se repite el gate de forma progresiva;
- si el equipo no soporta N grabaciones, la UI muestra el límite observado sin
  detener los N previews.

### Transferencia

La opción Transferencia permanece separada y funcional. El repositorio debe
seleccionar una fuente ADB concreta. La primera versión multimirror no promete
transferencias simultáneas desde varias fuentes; serializa una transferencia a
la vez y mantiene, cuando el hardware lo permita, los previews de las otras
fuentes.

## Recursos y calidad adaptativa

N conexiones ADB no garantizan N decodificaciones estables. Antes de abrir
una fuente se evalúa:

- ancho de banda USB observado;
- cantidad de decoders H.264 concurrentes disponibles;
- memoria;
- temperatura y throttling;
- espacio para grabación;
- energía y estabilidad del hub;
- FPS/drops de las fuentes ya abiertas.

Perfil inicial recomendado:

| Mirrors | Perfil inicial de laboratorio | Escalado posterior |
|---:|---|---|
| 1 | configuración actual, 30 fps/8 Mbps | mantener regresión existente |
| 2 | 30 fps, bitrate/resolución limitados por matriz | aumentar solo tras soak test |
| 3 | baseline 720p30 o límite equivalente, bitrate acotado | subir calidad si los tres permanecen estables |
| 4–6 | perfil reducido obtenido por matriz | aumentar por fuente solo si todas permanecen estables |

Los valores finales se obtienen por matriz; no se codifican por marca o tipo de
pantalla. La app publica `maxConcurrentSources` y no falla silenciosamente al
abrir una fuente por encima de la capacidad homologada.

## Navegación

Se conservan las rutas singulares actuales:

```text
/requisitions/:requisitionId/acquisitions/:sessionId/connect
/requisitions/:requisitionId/acquisitions/:sessionId/mirror
```

Se agregan rutas explícitas para multimirror:

```text
/requisitions/:requisitionId/acquisitions/:sessionId/mirrors/connect
/requisitions/:requisitionId/acquisitions/:sessionId/mirrors/live
```

- `requisitionId` y `sessionId` permanecen en path;
- los `deviceId` USB son efímeros y se recuperan desde el repositorio de sesión,
  no como única fuente de verdad en `extra`;
- si una ruta se restaura sin handles nativos, muestra la selección y permite
  reconectar todas las fuentes guardadas;
- no se usa `StatefulShellRoute` porque no existe navegación persistente por
  ramas;
- los ViewModels no navegan ni reciben `BuildContext`.

Al finalizar la migración, la tarjeta **Mirror** permite seleccionar entre uno y
`maxConcurrentSources` objetivos. La tarjeta **Capturadora** abre las mismas
rutas con `preferredTransport=hdmiUvc`; Mirror usa
`preferredTransport=androidAdbScrcpy`. Esa preferencia ordena y explica, pero no
oculta la otra clase conectada. La ruta singular se conserva como compatibilidad
y fallback. No se crean rutas `capture-card/multi` ni otro workspace.

## Workspace responsive

Todas las fuentes permanecen activas en todos los tamaños; cambia la composición,
no las capacidades.

- **Compact `<600`:** una fuente principal controlable y una tira horizontal de
  previews vivos/estados construida con builder; tocar uno cambia la fuente
  enfocada.
- **Medium `600..839`:** grid de dos columnas o una fuente principal con panel
  de fuentes según constraints de altura.
- **Expanded `840..1199`:** grid adaptable de dos columnas; la fuente enfocada
  puede ocupar más espacio sin ocultar las otras.
- **Large `>=1200`:** tres columnas simultáneas cuando cada preview conserva un
  ancho legible; con seis fuentes forma 3x2 y puede degradar a dos columnas.
- **Altura `<480`:** fuente enfocada + tira de previews, controles esenciales y
  diagnóstico en hoja/modal.

La composición usa `LayoutBuilder`, `Expanded`/`Flexible`, `GridView.builder` y
`ListView.builder`. No depende de orientación, marca ni tipo físico. Mantiene
SafeArea, escalado de texto, mouse, teclado, foco y targets mínimos de 48 dp.

Cada celda muestra:

- número/alias dinámico y nombre del objetivo;
- badge de transporte/capacidad;
- fase de conexión;
- preview o error local;
- indicador de fuente controlada solamente si `canControl`;
- FPS/drops/temperatura cuando esté disponible;
- Capturar y Grabar/Detener;
- Reconectar o Cerrar solamente esa fuente.

## Fases de implementación

### Fase MM0 — inventario y diagnóstico del ORICO

- registrar modelo impreso, puertos y cargador PD;
- comparar enumeración directa versus ORICO;
- capturar interfaces/endpoints;
- implementar errores tipados por etapa;
- clasificar candidatos ADB y retirar fallback no ADB.

**Salida:** causa reproducible del caso “solo carga”.

### Fase MM1 — un mirror mediante ORICO

- conectar un objetivo por cada USB-A, uno a la vez;
- conservar el pipeline singular existente;
- corregir selección, permiso, reenumeración o handshake cuando Android sí
  publique ADB;
- validar control, captura, grabación y transferencia;
- repetir sin PD y con PD.

**Salida:** un mirror estable mediante cualquiera de los tres USB-A aprobados.

### Fase MM2 — registro de sesiones nativas

- crear `AdbDeviceSessionRegistry`;
- mover conexión, transporte, streams, decoder, texture y recorder al objeto de
  sesión;
- hacer APIs y eventos source-scoped;
- detach y cleanup por dispositivo;
- adaptar el Mirror singular al registro con una fuente.

**Salida:** arquitectura multisesión sin regresión del caso singular.

### Fase MM3 — dos mirrors

- seleccionar y autorizar A/B;
- abrir A y luego B sin cerrar A;
- previews y control por foco;
- captura individual;
- una y luego dos grabaciones;
- detach/reconnect de B sin afectar A;
- soak test 60 minutos.

**Salida:** dos mirrors/control independientes y estables.

### Fase MM4 — tres mirrors

- agregar C sobre la arquitectura aprobada de dos;
- implementar admisión de recursos y calidad adaptativa;
- validar preview simultáneo A/B/C;
- control por foco y acciones por fuente;
- detach/reconnect de A, B y C de forma individual;
- validar grabaciones concurrentes según capacidad observada;
- soak test 60 minutos y sesión extendida definida por operación.

**Salida:** tres mirrors estables. Si el inspector actual no admite tres
decoders, MM4 no se considera terminada: se reduce el perfil o se homologa otro
inspector capaz de sostenerlos.

### Fase MM5 — escalado dinámico y hub de seis puertos

- retirar cualquier constante funcional de máximo tres;
- derivar `maxConcurrentSources` por capacidades y política homologada;
- conectar progresivamente 4, 5 y 6 objetivos en un hub alimentado de seis
  USB-A de datos;
- verificar que cada nueva fuente usa su propia conexión, transporte, streams,
  decoder, textura, recorder y cleanup;
- validar que alcanzar el límite no cierre ni degrade silenciosamente fuentes
  existentes;
- probar detach/reconnect de cualquiera de las seis;
- medir recursos y ajustar perfil sin introducir condiciones por marca.

**Salida:** la misma arquitectura abre N fuentes y una combinación homologada
demuestra seis mirrors. Si el inspector de la matriz inicial no puede con seis,
se homologa otro; no se hardcodea el software a tres.

### Fase MM6 — UI, navegación y evidencia

- selector de N dispositivos con estados individuales y límite visible;
- rutas plurales restaurables;
- workspace responsive para 1..N;
- foco de control accesible;
- captura/grabación ligadas a la fuente correcta;
- panel compartido de evidencias con fuente activa visible, inventario completo,
  miniaturas de video locales cacheadas con extractor alternativo, retención de
  previews fuera del viewport, alternancia cuadrícula/lista y difuminado por
  capa visual no destructiva;
- inicialización diferida del panel y conservación de sus previews al ocultarlo,
  sin repetir la preparación completa en cada apertura;
- logs, diagnóstico y errores redactados;
- fallback al Mirror singular.

**Salida:** flujo de producto completo dentro de requisa/sesión.

### Fase MM7 — hardening y homologación

- 20 ciclos attach/detach por puerto y objetivo;
- permutar objetivos entre todos los USB-A del hub probado;
- aceptar RSA nuevo, ya autorizado y revocado;
- desconectar durante control, captura y grabación;
- background/foreground y proceso terminado;
- PD conectado/desconectado;
- medir temperatura, batería, CPU, memoria, FPS y drops;
- repetir con 1, 2, 3 y, cuando exista el hub de seis puertos, 4/5/6 durante 60
  minutos;
- verificar hashes, MP4 y atribución de fuente.

**Salida:** combinación exacta inspector + hub + cargador + cables + objetivos
homologada para operación, primero con ORICO/3 y luego con hub ampliado/6.

### Fase MM8 — unificación con Capturadora HDMI/UVC

Esta es la siguiente fase de producto después de los ajustes leves y la
validación física ADB pendiente. Su implementación se divide en gates para no
poner en riesgo el flujo actual:

1. introducir `LiveVideoSource`, transporte y capabilities, adaptando las
   fuentes ADB existentes sin cambiar handshake, scrcpy, decoder o recorder;
2. extender argumentos y estado multi para que control y `controlStreamId` sean
   opcionales;
3. implementar y homologar una UGREEN directa mediante el adapter Android UVC;
4. agregar esa fuente al inventario/selector existentes con badge propio;
5. abrir una UVC sola en el workspace single y plural;
6. validar 1 ADB + 1 UVC por ORICO;
7. validar 2 ADB + 1 UVC por ORICO durante 60 minutos;
8. probar captura/grabación por fuente, reload, pérdida de señal, detach y
   reconexión sin afectar las otras;
9. actualizar admisión a `maxConcurrentSources` y repetir 4/5/6 con mezcla en
   un hub alimentado cuando exista hardware homologado.

**Salida:** Mirror y Capturadora conservan entradas distintas en el launcher,
pero llegan al mismo selector/workspace. El ORICO presenta dos fuentes
controlables ADB y una fuente UVC no controlable, todas operativas a la vez.

## Matriz de pruebas obligatoria

| Prueba | 1 mirror | 2 mirrors | 3 mirrors ORICO | 4–6 mirrors hub ampliado |
|---|---:|---:|---:|---:|
| Todos los objetivos enumerados como ADB | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Permiso/RSA independiente | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Preview 60 min | Obligatoria | Obligatoria | Obligatoria | Obligatoria por cantidad |
| Control por foco | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Captura por fuente | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Una grabación activa | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Grabación por cada fuente | N/A | Gate de capacidad | Gate de capacidad | Gate de capacidad |
| Detach de una fuente sin afectar otras | N/A | Obligatoria | Obligatoria | Obligatoria |
| Reconexión individual | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Transferencia singular sin regresión | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| PD y estabilidad de energía | Obligatoria | Obligatoria | Obligatoria | Obligatoria |

### Matriz adicional de mezcla UVC

| Prueba | 1 UVC directa | 1 ADB + 1 UVC | 2 ADB + 1 UVC ORICO | Mezcla 4–6 |
|---|---:|---:|---:|---:|
| Inventario y badge correctos | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Preview 60 min | Obligatoria | Obligatoria | Obligatoria | Obligatoria por cantidad |
| Control oculto en UVC | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Control ADB no afectado | N/A | Obligatoria | Obligatoria | Obligatoria |
| Captura por fuente y atribución | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Grabación UVC y ADB | Obligatoria | Obligatoria | Obligatoria | Gate de capacidad |
| Pérdida HDMI sin cerrar ADB | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Detach de UVC sin cerrar ADB | Obligatoria | Obligatoria | Obligatoria | Obligatoria |
| Detach ADB sin cerrar UVC | N/A | Obligatoria | Obligatoria | Obligatoria |
| Reload solo de la fuente elegida | Obligatoria | Obligatoria | Obligatoria | Obligatoria |

## Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| El objetivo solo carga y no enumera | No existe transporte ADB | Snapshot de descriptores, cable probado, roles/PD y matriz por puerto |
| El hub/HID aparece como objetivo | Handshake contra dispositivo incorrecto | Clasificación exacta por interfaz ADB |
| Detach global cierra todo | Pérdida de todas las fuentes | Registro por `deviceId` y cleanup source-scoped |
| Reenumeración vincula el teléfono equivocado | Control/evidencia mal atribuida | Correlación por identidad USB y confirmación del operador |
| Energía insuficiente | Resets, carga intermitente | PD homologado, conectar secuencialmente, medir estabilidad |
| N decoders no disponibles | Una fuente adicional falla | Admission control, `maxConcurrentSources` y calidad adaptativa |
| Temperatura/throttling | Drops y cierres | Bitrate/resolución escalables y límites operativos |
| Grabaciones concurrentes saturan IO | MP4 corrupto/drops | Gates progresivos 1..N y límite visible de recorders |
| El código asume tres fuentes | Hub de 6 exige reescritura | Map/lista dinámica y `maxConcurrentSources` calculado |
| Evidencia atribuida al slot incorrecto | Riesgo probatorio | `sourceSessionId` obligatorio en toda operación |
| Refactor rompe Mirror singular | Regresión funcional | Adaptar singular como sesión de tamaño 1 y matriz de regresión |

## Definición de terminado

La funcionalidad se considera completa cuando:

1. el caso de un objetivo que inicialmente solo cargaba tiene un diagnóstico
   concluyente y, cuando Android enumera ADB, conecta mediante File Cast;
2. N objetivos se enumeran y autorizan independientemente, con ORICO homologado
   para tres y una matriz ampliada prevista para seis;
3. todas las fuentes activas mantienen previews simultáneos durante 60 minutos;
4. el control se dirige exclusivamente a la fuente enfocada;
5. retirar o reconectar una fuente no interrumpe las otras;
6. captura y grabación se atribuyen a la fuente, requisa y sesión correctas;
7. Transferencia singular conserva el comportamiento actual;
8. la UI se adapta sin perder fuentes ni acciones;
9. el inspector ORICO homologado sostiene tres fuentes y el inspector/hub
   ampliado sostiene seis; otros inspectores publican su límite visible;
10. el selector lista a la vez ADB/scrcpy y HDMI/UVC con capacidades correctas;
11. dos fuentes ADB y una UVC funcionan simultáneamente en el ORICO, sin que
    detach, error, reload, captura o grabación de una afecte a las otras;
12. Mirror singular, Transferencia y evidencias no sufren regresiones.

## Fuentes

- [Android Developers — USB host](https://developer.android.com/develop/connectivity/usb/host)
- [scrcpy oficial](https://github.com/Genymobile/scrcpy/)
- [ORICO aportado por el propietario — ASIN B0BYS4D3KR](https://www.amazon.com.be/-/en/ORICO-Ethernet-Docking-Station-Multiport/dp/B0BYS4D3KR)
