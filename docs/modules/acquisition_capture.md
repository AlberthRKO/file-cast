# Módulo de captura Android

## Alcance implementado

La captura Android está vinculada desde la ruta a `requisitionId` y `sessionId`. La conexión dejó de exponer las fases técnicas de laboratorio: al elegir el dispositivo solicita permiso USB cuando corresponde, completa el handshake ADB, instala el servidor scrcpy 2.7 incluido, abre video/control, crea la textura y navega al workspace.

El workspace muestra el CUD de la requisa, el espejo táctil, controles Android y las evidencias recientes. En anchos de 840 px o más usa dos paneles; en compact mantiene el espejo como contenido principal y presenta una tira horizontal de evidencias sin cubrir la superficie táctil.

Durante una grabación, el botón cambia a estado de detención y muestra `mm:ss` actualizado cada segundo. Las confirmaciones de captura/video y los errores se presentan como un overlay dentro del espejo: no alteran la altura de los controles y desaparecen automáticamente (1 segundo para confirmaciones y 4 segundos para errores).

La sesión es reutilizable mientras ADB, textura y decoder continúen activos. Volver desde el workspace y seleccionar nuevamente el mismo dispositivo no reinicia el handshake ni crea otro decoder. Cada intento de handshake tiene una generación propia para impedir que el timeout de un intento anterior cierre una conexión posterior.

## Estructura

```text
lib/domain/
├── models/acquisition.dart
└── repositories/acquisition_repository.dart
lib/data/
├── repositories/acquisition_repository_impl.dart
└── services/android_acquisition_platform_service.dart
lib/ui/features/acquisition/
├── connect/
│   ├── view_models/acquisition_connect_view_model.dart
│   └── views/usb_device_list_view.dart
└── mirror/
    ├── view_models/mirror_view_model.dart
    ├── views/mirror_view.dart
    └── widgets/evidence_thumbnail.dart
android/app/src/main/kotlin/com/fiscalia/file_cast/
├── scrcpy/ScrcpyRecorder.kt
└── usb/UsbPlugin.kt
```

El flujo respeta `View -> ViewModel -> Repository -> Service`. El servicio de plataforma es el único componente Flutter que conoce `AdbClient`, assets, archivos temporales y disponibilidad Android. Las Views reciben estado y emiten intenciones.

## Capturas y grabaciones

- La foto ejecuta `exec:screencap -p` sobre un stream ADB independiente.
- Los bytes se escriben directamente en almacenamiento privado; no cruzan MethodChannel.
- Se valida la firma PNG, se limita la captura a 32 MiB y se calcula SHA-256 durante la escritura.
- La grabación reutiliza el H.264 recibido de scrcpy: el mismo paquete alimenta el decoder y `MediaMuxer`.
- Al pulsar **Grabar video**, el recorder entra en `starting` y espera el siguiente keyframe posterior a la intención del operador. El servidor scrcpy solicita un intervalo de keyframe de un segundo (`video_codec_options=i-frame-interval=1`) para que este inicio no dependa del GOP largo predeterminado del encoder. El botón muestra **Preparando…** y el contador comienza únicamente cuando ese frame ya fue escrito; no se precargan imágenes anteriores al toque.
- La configuración H.264 acumula los paquetes de codec y selecciona los SPS/PPS más recientes. El recorder valida que ambos existan y los entrega al track como CSD con start code Annex-B, según el contrato Android de AVC.
- Las muestras del encoder de scrcpy se entregan a `MediaMuxer` sin convertirlas nuevamente a AVCC. Los PTS se normalizan desde el keyframe inicial, se escribe una muestra EOS vacía para cerrar la duración del último frame y el contenedor se finaliza primero como `.part`.
- Antes de calcular SHA-256 y registrar la evidencia, `MediaMetadataRetriever` verifica que el MP4 final contenga una pista de video y dimensiones válidas. Un archivo incompleto se elimina y se informa en el mirror; nunca se cifra ni entra a la outbox.
- Si un encoder ignora el intervalo solicitado y el stream no entrega un keyframe dentro de 20 segundos, el inicio se cancela, se elimina el parcial y se informa el error. Así el MP4 siempre comienza en una muestra sincronizable sin sumar segundos anteriores ni desalinear el contador visible.
- El archivo válido se cifra, persiste en SQLite/SQLCipher y queda visible inmediatamente en el workspace. Su badge se actualiza desde la outbox local (`Pendiente`, `Subiendo`, `Sincronizada` o `Error`) sin recargar las miniaturas existentes.

La captura nativa se crea transitoriamente en `filesDir/evidence/<requisitionId>/<sessionId>`. Después de validarla y calcular el hash, el repositorio común la cifra como FCE, elimina el plano y persiste metadata/outbox en SQLite SQLCipher. Este pipeline conserva integridad local, pero todavía no sustituye el ledger inmutable de cadena de custodia pendiente.

## Control del dispositivo

- Tap, pulsación y arrastre se serializan como `INJECT_TOUCH_EVENT` del protocolo scrcpy 2.7.
- Cada evento transporta el `pointerId` real entregado por Flutter, equivalente al `fingerId` que usa el cliente oficial para una pantalla táctil. La resolución es la anunciada por el stream de video; `wm size` queda únicamente como diagnóstico porque scrcpy descarta posiciones declaradas para otro tamaño.
- La superficie interactiva escala desde el rectángulo exacto de la textura, no desde la ventana ni desde la densidad física del inspector. El factor usado es `videoWidth/renderWidth` y `videoHeight/renderHeight`; el `devicePixelRatio` no se aplica porque se cancelaría, igual que en el cálculo del cliente Flutter de referencia.
- `MediaCodec.INFO_OUTPUT_FORMAT_CHANGED` actualiza el tamaño visible real (incluido el crop del codec). El cambio se propaga por `mirror_state` al servicio, la sesión y el ViewModel, por lo que una rotación del objetivo no continúa enviando las dimensiones iniciales.
- Mouse y trackpad usan el mismo canal; la rueda se convierte al formato fixed-point de 16 bits de scrcpy 2.7.
- La cola nativa de control está acotada a 256 mensajes y compacta movimientos antiguos para evitar latencia creciente o consumo de memoria.
- El primer `A_OKAY` de cada stream confirma `A_OPEN` y no se reutiliza como confirmación de `A_WRTE`. De esta manera solo existe un paquete de control sin confirmar y `DOWN`, `MOVE` y `UP` conservan su orden en USB.
- El botón de diagnóstico del AppBar muestra resolución del header, salida vigente de MediaCodec, resolución incluida en el paquete táctil, último gesto, paquetes encolados/confirmados/fallidos, estado de espera del keyframe de grabación y salida acumulada de scrcpy-server. Si `queued` y `acknowledged` avanzan pero el servidor informa `different device size`, el problema es la resolución; si coinciden las resoluciones y el fabricante rechaza la inyección, debe habilitarse el ajuste de seguridad del objetivo.
- Algunos fabricantes exigen habilitar adicionalmente “Depuración USB (ajustes de seguridad)” para aceptar inyección táctil. File Cast no puede activar esa autorización del objetivo.

El repositorio `diyews/scrcpy-flutter` se usó como referencia para captura de puntero y escalado, pero no se copió su serialización: utiliza un servidor personalizado antiguo y un mensaje táctil de 28 bytes. File Cast usa el servidor oficial 2.7 verificado y, por tanto, conserva el mensaje de 32 bytes con `action_button` y `buttons`, tal como exige esa versión.

La clave RSA del inspector se conserva en preferencias privadas. Una reconexión física reutiliza la clave, pero Android puede volver a pedir confirmación si el usuario no eligió “Permitir siempre”, si revocó autorizaciones o si el objetivo eliminó sus claves ADB.

## Navegación

Se conservan las rutas restaurables:

```text
/requisitions/:requisitionId/acquisitions/:sessionId/connect
/requisitions/:requisitionId/acquisitions/:sessionId/mirror
/requisitions/:requisitionId/acquisitions/:sessionId/transfer
```

El identificador de textura continúa viajando como argumento efímero tipado porque no puede restaurarse después de reiniciar el proceso. La ruta conserva un fallback visible cuando ese argumento no existe.

La conexión base ADB se separó del arranque del mirror. `connectForTransfer` puede reutilizar la autorización y el transporte existentes sin instalar/iniciar scrcpy; `connectAndStart` compone esa conexión base con el pipeline de espejo. El destino `transfer` viaja como query parameter de la pantalla de conexión y los IDs de negocio permanecen en el path.

## Plataforma y seguridad

- Android requiere USB host, depuración USB habilitada y autorización RSA del objetivo.
- iOS/iPadOS muestra capacidad no disponible y no invoca MethodChannel ADB.
- Se retiró el permiso `HARDWARE_TEST` y el receiver estático redundante.
- El PendingIntent de permiso USB se limita explícitamente al paquete de la app.
- Se mantiene scrcpy 2.7; actualizarlo exige actualizar cliente/servidor juntos y ejecutar la matriz física.

## Pendiente antes de piloto

- Completar el ledger inmutable de cadena de custodia y su validación probatoria end-to-end; el índice local, cifrado FCE y outbox ya están persistidos.
- Validar en hardware la subida reanudable, pausa/reintento y recuperación mediante WorkManager con pérdida real de red y reinicio de proceso.
- Medición de espacio y backpressure/colas acotadas para sesiones largas.
- Manejo completo de background, extracción de cable y recuperación del proceso; la rotación del objetivo ya actualiza el tamaño táctil, pero debe cubrirse en la matriz física.
- IDs y errores tipados; los modelos manuales deben migrar a Freezed junto con el generador acordado.
- Validación física del MP4 corregido, reproducción tras desconexión y matriz Android.

## Validación

Por regla del repositorio no se ejecutaron `flutter test`, `flutter analyze`, `flutter run`, builds nativos ni generadores. Se aplicó `dart format` y se revisaron referencias y diffs. El propietario debe validar en el SDK fijado y en hardware OTG real.
