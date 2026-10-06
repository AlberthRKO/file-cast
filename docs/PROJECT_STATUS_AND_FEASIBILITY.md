# Estado y viabilidad de File Cast

Fecha de revisión inicial: 27 de agosto de 2026  
Actualización de arquitectura UI: 31 de agosto de 2026  
Limpieza de infraestructura Flutter: 31 de agosto de 2026
Actualización de adquisición Android: 4 de septiembre de 2026
Actualización de transferencia Android: 8 de septiembre de 2026
Actualización de previews de video y ciclo de vida del mirror: 6 de octubre de 2026
Plan de adquisición USB iPhone: 10 de septiembre de 2026
Actualización de cifrado local y outbox FCE: 29 de septiembre de 2026
Alcance revisado: Flutter/Dart, Android nativo Kotlin, configuración iOS, documentación, historial Git reciente, mockups adjuntos y validadores locales.

## Dictamen ejecutivo

El proyecto es **viable por etapas**, con una diferencia esencial entre plataformas:

- **Android objetivo -> Android inspector por USB:** viable para dispositivos desbloqueados, con USB debugging autorizado y Android 5.0/API 21 o superior para el flujo scrcpy actual. El repositorio ya demuestra detección USB, autenticación ADB, streaming H.264 y envío de eventos de control.
- **Captura, grabación y transferencia Android ligadas a una requisa:** existen verticales locales que guardan PNG/MP4/archivos en almacenamiento privado, calculan SHA-256 y registran metadatos contra requisa/sesión. El browser inicia con ubicaciones comunes y puede recorrer `/sdcard` completo dentro de los permisos de `shell`. Aún faltan persistencia del catálogo, almacenamiento inmutable, ledger, sincronización y validación física.
- **iPhone/iPad objetivo -> otro móvil inspector por cable, con espejo y control tipo scrcpy:** no es viable con APIs públicas de iOS como una réplica directa de ADB/scrcpy. No existe en el proyecto ni en los frameworks públicos revisados una interfaz equivalente para controlar otro iPhone por USB.
- **iOS con alcance ajustado:** el producto descarta como flujo principal instalar
  una app compañera o exigir una computadora. El mirror se investigará mediante
  HDMI/UVC y la transferencia mediante una PoC futura de `libimobiledevice` en
  un inspector Android USB Host. AFC solo expone partes autorizadas; no se
  promete control táctil ni acceso completo al sistema de archivos.
- **Uso probatorio/forense:** todavía no está listo. En el estado actual es una prueba técnica de conectividad y UI, no una herramienta de adquisición forense validada.

La recomendación es construir primero un MVP Android de extremo a extremo y mantener iOS como un adaptador de capacidades distinto, sin prometer paridad falsa.

## Qué existe hoy

| Capacidad | Estado observado | Resultado |
|---|---|---|
| Flavors Flutter | `development`, `staging`, `production`, `cliente1`, `cliente2` | Base disponible |
| Login | Formulario MVVM conectado a `file-cast-back /api/v1/auth/*`, tokens seguros, restauración y refresh | Implementado en la rama `feat/implemetacion-login`; falta validación del propietario |
| Listado de requisas | Feature MVVM adaptativa con lista/grid/tabla, filtros y carga progresiva | Conectado a `GET /api/v1/requisitions`; cache offline y resolución de conflictos pendientes |
| Crear requisa | Ruta `/requisitions/new` con modo CUD/persona, busquedas, fecha/hora, ubicacion visual y navegacion a conexion | Parcial; registro simulado, mapa/GPS nativo y persistencia offline reales pendientes |
| Detalle de requisa | Cabecera fija adaptativa caso/persona, sujetos, participantes, ubicación, vínculo CUD, sesiones, evidencias y acciones | Implementado contra `GET /api/v1/requisitions/:id`; búsqueda/vínculo mediante `POST /api/v1/requisitions/:id/case-links`, creación de sesiones y sellado conectados; cabecera colapsable, estados de sincronización y preview local/remoto disponibles |
| Archivos/evidencias por requisa | Resumen por categoría/peso, selector múltiple de imágenes, videos, audios y documentos, cifrado local, outbox, sincronización y preview | Implementado como vertical local: selección múltiple con preview antes de confirmar, sesión creada al aceptar, importación cifrada, carga en segundo plano con progreso por lote, reintento visible, miniaturas y preview de imágenes, videos, audio, PDF y texto/DOCX; pendiente validación probatoria end-to-end y preview de cifrados desde otro dispositivo |
| Offline y sincronización | SQLite SQLCipher, outbox de evidencias FCE y reintento al recuperar conectividad | Implementación local; sincronización real depende de sesión/autenticación API |
| USB host Android | Detección, permisos, attach/detach | Implementado como prototipo |
| ADB por USB | Handshake RSA, streams multiplexados, shell y push | Implementado como prototipo |
| Espejo Android | scrcpy server 2.7, H.264, `MediaCodec` y `Texture` | Demostrado en código |
| Control Android | Touch, arrastre, mouse/trackpad y teclas por canal scrcpy 2.7 | Implementado y validado en hardware por el propietario; algunos fabricantes requieren un ajuste de seguridad adicional |
| Foto de la pantalla | `exec:screencap -p`, PNG privado, validación de firma y SHA-256 | Implementado como vertical local |
| Grabación | GOP H.264 acotado, conversión Annex-B a AVC/AVCC, `MediaMuxer`, contador, MP4 privado y SHA-256 | Implementado en código; requiere revalidación física del MP4 generado |
| Transferencia desde objetivo | Browser de almacenamiento compartido con ADB Sync `LIST`/`STAT`/`RECV`, preview temporal de imágenes/videos/audios/PDF/DOCX/texto, selección múltiple, progreso, cancelación, temporal privado y SHA-256 | Implementación local inicial; falta validación física, preview ofimático legado, persistencia probatoria y deduplicación |
| Integración iOS | `AppDelegate` estándar, sin canal/plugin de adquisición; plan USB/AFC documentado | No implementado; PoC diferida hasta cerrar Android |
| Cifrado de evidencias | FCE AES-256-GCM por bloques, hashes plano/ciphertext y clave envuelta en bóveda segura | Implementado en código y documentado; recuperación institucional pendiente |
| Cadena de custodia | No hay ledger, manifiesto, hash por evidencia ni sellado | Depende de la integración completa con el backend |
| Pruebas | Existe prueba del servicio FCE | Debe ejecutarse con Flutter 3.35/Dart 3.9 en CI |

## Evidencia en el repositorio

### Flujo Android nativo

La prueba técnica está concentrada en:

- `android/app/src/main/kotlin/com/fiscalia/file_cast/usb/UsbPlugin.kt`: canales Flutter, ciclo USB, conexión ADB, textura, mirror y control.
- `android/app/src/main/kotlin/com/fiscalia/file_cast/usb/UsbAdbTransport.kt`: endpoints bulk, protocolo ADB, multiplexación, sync push y lectores de video/control.
- `android/app/src/main/kotlin/com/fiscalia/file_cast/adb/AdbAuth.kt`: claves RSA y autenticación ADB.
- `android/app/src/main/kotlin/com/fiscalia/file_cast/scrcpy/ScrcpyDecoder.kt`: decodificación H.264 hacia una superficie.
- `android/app/src/main/kotlin/com/fiscalia/file_cast/scrcpy/ScrcpyControl.kt`: paquetes touch, key y scroll.
- `lib/core/adb/adb_client.dart`: fachada Dart sobre `MethodChannel`/`EventChannel`.
- `lib/data/services/android_acquisition_platform_service.dart`: frontera de plataforma que coordina USB/ADB/scrcpy sin exponer IO a la View.
- `lib/ui/features/acquisition/connect/view_models/acquisition_connect_view_model.dart`: estado y comandos de conexión automática.
- `lib/ui/features/acquisition/mirror/views/mirror_view.dart`: workspace responsive de espejo y evidencias.
- `android/app/src/main/kotlin/com/fiscalia/file_cast/scrcpy/ScrcpyRecorder.kt`: remultiplexado local del H.264 a MP4.
- `lib/ui/features/acquisition/mirror/`: View responsive, ViewModel de controles/logs, textura y traducción de coordenadas.

El asset incluido es `scrcpy-server-v2.7.jar`, de aproximadamente 70 KiB, con SHA-256 actual:

```text
a23c5659f36c260f105c022d27bcb3eafffa26070e7baa9eda66d01377a1adba
```

La documentación [ADB_HANDSHAKE.md](ADB_HANDSHAKE.md) describe las fases 1 a 5, pero ya quedó detrás del código: menciona `control=false`, mientras que el comando actual inicia scrcpy con `control=true` y el historial contiene fases 6 y 7.

### Flujo Flutter de negocio

- Login y Started viven en `lib/ui/features/`, con navegación declarativa y estado separado de la composición visual.
- La interfaz `AuthRepository`, el repositorio remoto y el gestor de sesión persistente ya están registrados por inyección; los casos de uso siguen siendo reutilizables por las Views.
- El listado usa un `RequisitionListViewModel`, estado Freezed y un `RequisitionRepository` remoto registrado por inyección. Crear y abrir detalle ya tienen rutas/features reales; el detalle consulta el backend y conserva un outbox local para evidencias pendientes.
- La inyección ya registra autenticación remota, sesión persistente y refresh, además de los repositorios remotos de listado, detalle y creación; caché, reconciliación y sincronización probatoria siguen pendientes.

La estructura Flutter activa ya usa `lib/ui`, MVVM en las pantallas de producto, `MaterialApp.router`, `go_router`, tema central y adaptación por constraints. Se retiraron `lib/presentation`, ScreenUtil, los helpers por porcentaje/orientación y las rutas imperativas. La consola técnica de conexión fue sustituida por ViewModel, repositorio y servicio de plataforma; la deuda principal de adquisición pasa a ser persistencia/ledger, recuperación de sesión, errores tipados y validación física.

### iOS

`ios/Runner/AppDelegate.swift` únicamente registra los plugins generados. No hay implementación Swift/Objective-C para USB, ReplayKit, PhotoKit, documentos, captura ni transferencia. Las orientaciones sí están habilitadas para iPhone/iPad.

## Hallazgos priorizados

### P0 — imprescindibles antes de tratar archivos como evidencia

1. **No existe cadena de custodia.** Cada evidencia debe tener identidad, fuente, operador, requisa, sesión de adquisición, timestamps UTC/monotónico, tamaño, MIME, método de captura, hash SHA-256 y eventos inmutables de custodia.
2. **La base probatoria local está en implementación inicial.** Ya existe cifrado FCE, SQLite SQLCipher, hashes y outbox; todavía faltan escritura atómica completa en todos los adaptadores, cuota, recuperación tras cierre inesperado, retención y borrado controlado.
3. **El vínculo local todavía no es probatorio.** Las rutas, sesiones, carpetas y metadatos ya reciben `requisitionId` y `sessionId`, pero el catálogo continúa en memoria y falta un ledger persistente que impida reasignar o modificar evidencias.
4. **El alcance iOS necesita redefinición contractual.** La captura/control por cable desde otro móvil no puede prometerse como equivalente a Android.
5. **Se necesita autorización explícita y procedimiento operativo.** El producto debe registrar consentimiento/orden, operador y dispositivo antes de iniciar adquisición. La guía NIST de forense móvil separa preservación, adquisición, examen, análisis y reporte; la app debe reflejar esas fases.

### P1 — riesgos técnicos del prototipo Android

1. **Pull requiere validación física.** La primera vertical `LIST`/`STAT`/`RECV` ya escribe por streaming en almacenamiento privado, calcula SHA-256 y registra el resultado contra requisa/sesión. Falta probar fragmentación, archivos grandes, cancelación, desconexión y fabricantes de la matriz.
2. **Lectura exacta corregida.** `_readExact()` conserva excedentes por stream para no perder el inicio del video cuando comparte un chunk con los metadatos. Falta cubrirlo con pruebas de protocolo.
3. **Backpressure parcial.** La cola de control está acotada y compacta movimientos, y el pre-roll de grabación se limita a 24 MiB. Las colas generales de datos ADB todavía requieren límites y métricas para sesiones extensas.
4. **Ciclo de vida sensible.** Al abandonar mirror se libera la textura, el decoder, la grabación activa y la conexión nativa; al regresar se fuerza una sesión limpia. Todavía debe validarse ante cierre de proceso, cable retirado, background y grabación activa.
5. **Confirmación de control limitada.** `sendTouch()` propaga errores del canal y la UI los presenta, pero scrcpy no confirma individualmente que Android haya inyectado cada gesto; un fabricante todavía puede rechazarlo por sus ajustes de seguridad.
6. **Coordenadas y rotación unificadas, pendientes de matriz.** La textura usa su rectángulo renderizado, MediaCodec publica el tamaño/crop vigente y `wm size` quedó solo como diagnóstico. Deben repetirse las pruebas con letterboxing, recorte, rotación y varias resoluciones.
7. **Autenticación ADB sin endurecimiento.** La clave privada se persiste en `SharedPreferences`; para una herramienta sensible debe protegerse con Android Keystore y validarse contra vectores/pruebas AOSP. La generación de `n0inv` y la firma deben ser revisadas con pruebas de protocolo, no solo con un modelo de teléfono.
8. **scrcpy 2.7 está congelado dentro del APK.** El proyecto oficial ya publica una versión posterior y registra correcciones para Android recientes. Actualizar no es solo reemplazar el JAR: cambian opciones y protocolo. Se requiere política de versionado, hash permitido, matriz de compatibilidad y pruebas de regresión.
9. **Diagnóstico visible en UI.** La consola arbitraria fue retirada; el panel actual es de solo lectura y muestra tamaños, último gesto, estado del stream, confirmaciones ADB y salida de scrcpy-server. Debe ocultarse o condicionarse en builds operativos si los logs contienen datos sensibles.
10. **Licencias de terceros.** El repositorio no contiene un archivo de licencia/avisos para el servidor scrcpy distribuido. Debe incorporarse el cumplimiento Apache-2.0 y el inventario SBOM.

### P1 — riesgos de producto y datos

1. La creación de requisas y la sincronización de evidencias todavía tienen cobertura parcial; listado, detalle, sesiones y finalización ya consumen el backend, pero el login y el flujo completo aún deben validarse contra el backend local y el entorno institucional.
2. No hay API contractual, paginación real, control de concurrencia ni resolución de conflictos.
3. No hay máquina de estados de requisa (`borrador`, `en progreso`, `finalizada`, `sellada`, etc.).
4. No hay protección para impedir modificar una requisa finalizada.
5. No hay subida reanudable por partes ni recuperación institucional de claves.
6. No hay telemetría segura, trazas correlacionadas o códigos de error estables.

### P2 — arquitectura, responsive y mantenibilidad

1. La captura y grabación ya tienen una vertical MVVM/repositorio local; falta persistir el catálogo y separar el ledger inmutable del archivo derivado.
2. Transferencia tiene una vertical local inicial; sincronización, sellado, persistencia y cadena de custodia todavía no están completos.
3. `android.hardware.usb.host` quedó declarado como capacidad opcional; falta validar en distribución real que Android sin OTG mantenga disponible el módulo de gestión y bloquee únicamente adquisición.

### P2 — validación y toolchain

- `pubspec.yaml` exige Dart `^3.9.0` y Flutter `^3.35.0`.
- El entorno activo durante la auditoría tiene Dart 3.6.0 y Flutter 3.27.1.
- `flutter pub get` y `flutter analyze` no pudieron ejecutarse por esa incompatibilidad.
- Se agregó `test/data/services/evidence_crypto_service_test.dart`; todavía no se
  ejecutó porque el entorno activo no satisface el SDK mínimo del proyecto.
- No hay configuración FVM/mise versionada que instale o seleccione el SDK requerido.

Esto debe resolverse fijando una única versión de Flutter en CI y desarrollo antes de refactorizar.

## Archivos creados/modificados recientemente

El worktree estaba limpio para el código del producto al iniciar la revisión; solo `.agents/` y `skills-lock.json` aparecían sin seguimiento. El historial reciente muestra:

- 9–16 de julio: creación de USB/ADB, autenticación, streams, scrcpy, decoder, control y páginas de laboratorio.
- 23–24 de julio: login, started y primera infraestructura responsive, retirada después de la migración final.
- 24 de julio–19 de agosto: listado/filtros/cards de requisas simuladas.

Los commits más relevantes son `8fca950` (USB fase 1), `b39d77a` (ADB fase 2), `b04e0f6` (streams), `2451e1e` (mirror), `15e3c63`/`c0f7333` (control), `bb11b02` (responsive) y `5fed146` (cards de requisas).

## Frontera real por plataforma

### Android

Android ofrece USB host desde API 12, siempre que el hardware lo implemente. scrcpy requiere Android 5.0/API 21 como mínimo y USB debugging para el modo usado por este proyecto. Por tanto, “Android viejo” debe significar **Android 5.0 o posterior**, no cualquier Android histórico.

El producto puede:

- reflejar y controlar la pantalla bajo autorización ADB;
- generar una captura desde un comando binario o desde el pipeline de video;
- remultiplexar el H.264 recibido a MP4 mientras sigue mostrando la textura;
- enumerar y copiar almacenamiento compartido que sea accesible al usuario/shell;
- usar una app compañera y selectores del sistema para una transferencia con consentimiento más clara.

No debe prometer acceso a datos privados de otras apps, bypass de bloqueo, root ni extracción física. Son alcances distintos, sujetos a otras herramientas, validaciones y autorización legal.

### iOS/iPadOS

La ausencia de una API pública tipo ADB/scrcpy y el sandbox de iOS mantienen el
control remoto general por cable como **no viable**. Para File Cast se separan
las capacidades:

- mirror por salida HDMI y capturadora UVC;
- transferencia futura por cable hacia un inspector Android con
  `libimobiledevice`, usbmux, lockdownd y AFC;
- backup lógico mediante MobileBackup2 únicamente como fase posterior y
  evaluada por separado.

El target debe estar desbloqueado y aceptar confianza. El pairing puede alterar
registros del dispositivo y debe documentarse. AFC/House Arrest no equivalen a
un explorador total: exponen partes del contenido y documentos de aplicaciones
que habiliten File Sharing. El plan completo, gates y riesgos están en
[IOS_USB_LIBIMOBILEDEVICE_PLAN.md](IOS_USB_LIBIMOBILEDEVICE_PLAN.md).

## Criterio de salida de prototipo

El MVP Android estará listo para piloto cuando, como mínimo:

1. Login, CRUD de requisas, detalle y finalización funcionen con API y modo offline.
2. Toda conexión se cree dentro de una requisa y sesión de adquisición.
3. Captura, grabación y transferencia creen evidencias inmutables con hash verificado.
4. La app pueda recuperarse de cable retirado, rotación, background, poco espacio y proceso terminado.
5. Existan pruebas unitarias de repositorios/ViewModels, pruebas de protocolo nativo y pruebas de integración en una matriz de equipos.
6. El binario usado de scrcpy esté versionado, verificado y licenciado.
7. Un procedimiento de validación compare resultados contra fuentes conocidas y documente límites.
8. Una revisión jurídica/forense apruebe consentimiento, conservación, retención, acceso y reporte.

## Fuentes técnicas verificadas

- [Android USB host overview](https://developer.android.com/develop/connectivity/usb/host)
- [Proyecto oficial scrcpy](https://github.com/Genymobile/scrcpy/)
- [Flutter: guía de arquitectura](https://docs.flutter.dev/app-architecture/guide)
- [Flutter: diseño adaptive/responsive](https://docs.flutter.dev/ui/adaptive-responsive/general)
- [Apple ReplayKit](https://developer.apple.com/documentation/replaykit)
- [Apple Multipeer Connectivity](https://developer.apple.com/documentation/MultipeerConnectivity)
- [Apple UIDocumentPickerViewController](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller)
- [Apple External Accessory](https://developer.apple.com/documentation/externalaccessory)
- [Apple: captura de un iPhone/iPad conectado con QuickTime](https://support.apple.com/es-es/guide/quicktime-player/qtp356b55534/mac)
- [Apple: confiar en un equipo conectado](https://support.apple.com/es-lamr/109054)
- [libimobiledevice oficial](https://github.com/libimobiledevice/libimobiledevice)
- [usbmuxd oficial](https://github.com/libimobiledevice/usbmuxd)
- [NIST SP 800-101 Rev. 1 — Mobile Device Forensics](https://csrc.nist.gov/pubs/sp/800/101/r1/final)
