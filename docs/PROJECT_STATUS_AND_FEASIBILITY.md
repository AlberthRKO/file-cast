# Estado y viabilidad de File Cast

Fecha de revisión inicial: 27 de agosto de 2026  
Actualización de arquitectura UI: 31 de agosto de 2026  
Alcance revisado: Flutter/Dart, Android nativo Kotlin, configuración iOS, documentación, historial Git reciente, mockups adjuntos y validadores locales.

## Dictamen ejecutivo

El proyecto es **viable por etapas**, con una diferencia esencial entre plataformas:

- **Android objetivo -> Android inspector por USB:** viable para dispositivos desbloqueados, con USB debugging autorizado y Android 5.0/API 21 o superior para el flujo scrcpy actual. El repositorio ya demuestra detección USB, autenticación ADB, streaming H.264 y envío de eventos de control.
- **Captura de pantalla, grabación y transferencia Android ligadas a una requisa:** viables, pero todavía no están implementadas como evidencias. Falta capturar/guardar bytes, metadatos, hash, sesión y relación con la requisa.
- **iPhone/iPad objetivo -> otro móvil inspector por cable, con espejo y control tipo scrcpy:** no es viable con APIs públicas de iOS como una réplica directa de ADB/scrcpy. No existe en el proyecto ni en los frameworks públicos revisados una interfaz equivalente para controlar otro iPhone por USB.
- **iOS con alcance ajustado:** sí es viable mediante dos rutas: una app compañera en el equipo objetivo, con selección explícita de archivos y ReplayKit/red local; o una estación macOS conectada por cable para captura y adquisición autorizada. Ninguna de estas rutas ofrece control táctil remoto general del iPhone.
- **Uso probatorio/forense:** todavía no está listo. En el estado actual es una prueba técnica de conectividad y UI, no una herramienta de adquisición forense validada.

La recomendación es construir primero un MVP Android de extremo a extremo y mantener iOS como un adaptador de capacidades distinto, sin prometer paridad falsa.

## Qué existe hoy

| Capacidad | Estado observado | Resultado |
|---|---|---|
| Flavors Flutter | `development`, `staging`, `production`, `cliente1`, `cliente2` | Base disponible |
| Login | Formulario visual; el botón navega directamente al home | Mock, sin autenticación real |
| Listado de requisas | Feature MVVM adaptativa con lista/grid/tabla, filtros y paginación | Mock detrás de `RequisitionRepository` in-memory; API pendiente |
| Crear requisa | FAB sin acción funcional | No implementado |
| Detalle de requisa | No hay ruta, modelo ni pantalla | No implementado |
| Archivos/evidencias por requisa | No hay modelo, almacenamiento ni backend | No implementado |
| Offline y sincronización | Existen servicios generales de almacenamiento/conectividad, pero no un outbox de negocio | No implementado |
| USB host Android | Detección, permisos, attach/detach | Implementado como prototipo |
| ADB por USB | Handshake RSA, streams multiplexados, shell y push | Implementado como prototipo |
| Espejo Android | scrcpy server 2.7, H.264, `MediaCodec` y `Texture` | Demostrado en código |
| Control Android | Touch y teclas por canal de control scrcpy | Implementado, reportado como inestable en el historial |
| Foto de la pantalla | No hay comando ni persistencia de PNG/JPEG | No implementado |
| Grabación | No hay `MediaMuxer`, archivo MP4 ni estado de grabación | No implementado |
| Transferencia desde objetivo | Solo existe push inspector -> objetivo; no existe pull objetivo -> inspector | No implementado |
| Integración iOS | `AppDelegate` estándar, sin canal/plugin de adquisición | No implementado |
| Cadena de custodia | No hay ledger, manifiesto, hash por evidencia ni sellado | No implementado |
| Pruebas | Solo helpers; no existen archivos `*_test.dart` | Ausentes |

## Evidencia en el repositorio

### Flujo Android nativo

La prueba técnica está concentrada en:

- `android/app/src/main/kotlin/com/fiscalia/file_cast/usb/UsbPlugin.kt`: canales Flutter, ciclo USB, conexión ADB, textura, mirror y control.
- `android/app/src/main/kotlin/com/fiscalia/file_cast/usb/UsbAdbTransport.kt`: endpoints bulk, protocolo ADB, multiplexación, sync push y lectores de video/control.
- `android/app/src/main/kotlin/com/fiscalia/file_cast/adb/AdbAuth.kt`: claves RSA y autenticación ADB.
- `android/app/src/main/kotlin/com/fiscalia/file_cast/scrcpy/ScrcpyDecoder.kt`: decodificación H.264 hacia una superficie.
- `android/app/src/main/kotlin/com/fiscalia/file_cast/scrcpy/ScrcpyControl.kt`: paquetes touch, key y scroll.
- `lib/core/adb/adb_client.dart`: fachada Dart sobre `MethodChannel`/`EventChannel`.
- `lib/presentation/pages/presentation/mirror/usb_device_list_page.dart`: consola técnica que orquesta todas las fases.
- `lib/presentation/pages/presentation/mirror/mirror_page.dart`: textura, traducción de coordenadas y controles.

El asset incluido es `scrcpy-server-v2.7.jar`, de aproximadamente 70 KiB, con SHA-256 actual:

```text
a23c5659f36c260f105c022d27bcb3eafffa26070e7baa9eda66d01377a1adba
```

La documentación [ADB_HANDSHAKE.md](ADB_HANDSHAKE.md) describe las fases 1 a 5, pero ya quedó detrás del código: menciona `control=false`, mientras que el comando actual inicia scrcpy con `control=true` y el historial contiene fases 6 y 7.

### Flujo Flutter de negocio

- `lib/presentation/pages/login/login.dart` valida campos solo en UI y llama `context.pushNamed(Routes.home)`; no usa `AuthProvider` ni un repositorio.
- `lib/presentation/providers/auth_provider.dart` cambia a `unauthenticated` y nunca autentica.
- La interfaz `AuthRepository` y los casos de uso existen, pero no hay implementación registrada.
- `lib/presentation/pages/home/home.dart` quedó como adaptador de compatibilidad; la implementación vive en `lib/ui/features/requisitions/list/`.
- El listado usa un `RequisitionListViewModel`, estado Freezed y un `RequisitionRepository` in-memory registrado por inyección. Crear y abrir detalle siguen pendientes de sus rutas/features reales.
- La inyección todavía necesita repositorios reales para autenticación, API, caché, evidencias y adquisición; el repositorio de listado actual es reemplazable y solo conserva el prototipo visual.

La separación de carpetas sugiere Clean Architecture, pero no está conectada de extremo a extremo. Hoy buena parte de la lógica de adquisición reside en un `StatefulWidget` de más de 1.200 líneas.

### iOS

`ios/Runner/AppDelegate.swift` únicamente registra los plugins generados. No hay implementación Swift/Objective-C para USB, ReplayKit, PhotoKit, documentos, captura ni transferencia. Las orientaciones sí están habilitadas para iPhone/iPad.

## Hallazgos priorizados

### P0 — imprescindibles antes de tratar archivos como evidencia

1. **No existe cadena de custodia.** Cada evidencia debe tener identidad, fuente, operador, requisa, sesión de adquisición, timestamps UTC/monotónico, tamaño, MIME, método de captura, hash SHA-256 y eventos inmutables de custodia.
2. **No existe almacenamiento probatorio.** Faltan cifrado local, escritura atómica, verificación tras escritura, protección de claves, cuota, recuperación después de cierre inesperado y borrado controlado.
3. **La evidencia no está vinculada a la requisa.** La conexión ADB global no recibe `requisitionId` ni `acquisitionSessionId`.
4. **El alcance iOS necesita redefinición contractual.** La captura/control por cable desde otro móvil no puede prometerse como equivalente a Android.
5. **Se necesita autorización explícita y procedimiento operativo.** El producto debe registrar consentimiento/orden, operador y dispositivo antes de iniciar adquisición. La guía NIST de forense móvil separa preservación, adquisición, examen, análisis y reporte; la app debe reflejar esas fases.

### P1 — riesgos técnicos del prototipo Android

1. **No hay screenshot, recording ni pull.** `pushFile()` solo envía inspector -> objetivo. No existe el camino requerido objetivo -> inspector.
2. **El cliente `_readExact()` descarta cualquier excedente del último chunk.** Esto puede perder bytes si metadatos y el inicio del video llegan juntos. Debe existir un buffer por stream o toda la lectura exacta debe quedar del lado nativo.
3. **Backpressure insuficiente.** El reader ADB encola `ByteArray` sin límite y el loop de video hace `copyOf(size)` por paquete. Una desaceleración del decoder puede agotar memoria.
4. **Ciclo de vida incompleto.** Salir de `UsbDeviceListPage` no garantiza `stopMirror()`/`disconnectAdb()`. El proceso scrcpy y recursos nativos pueden quedar activos.
5. **Errores de control se ocultan.** `sendTouch()` y `sendKey()` capturan `PlatformException` y no la propagan; la UI no puede confirmar que la acción funcionó.
6. **Coordenadas y rotación necesitan un modelo único.** Se mezclan dimensiones del header, `wm size` y la textura. Deben contemplarse rotación, letterboxing, recorte, densidad y cambio de tamaño durante la sesión.
7. **Autenticación ADB sin endurecimiento.** La clave privada se persiste en `SharedPreferences`; para una herramienta sensible debe protegerse con Android Keystore y validarse contra vectores/pruebas AOSP. La generación de `n0inv` y la firma deben ser revisadas con pruebas de protocolo, no solo con un modelo de teléfono.
8. **scrcpy 2.7 está congelado dentro del APK.** El proyecto oficial ya publica una versión posterior y registra correcciones para Android recientes. Actualizar no es solo reemplazar el JAR: cambian opciones y protocolo. Se requiere política de versionado, hash permitido, matriz de compatibilidad y pruebas de regresión.
9. **Consola shell expuesta en UI.** El panel permite ejecutar comandos arbitrarios. Es útil para laboratorio, pero debe excluirse de builds operativos.
10. **Licencias de terceros.** El repositorio no contiene un archivo de licencia/avisos para el servidor scrcpy distribuido. Debe incorporarse el cumplimiento Apache-2.0 y el inventario SBOM.

### P1 — riesgos de producto y datos

1. El login y las requisas son mocks.
2. No hay API contractual, paginación real, control de concurrencia ni resolución de conflictos.
3. No hay máquina de estados de requisa (`borrador`, `en progreso`, `finalizada`, `sellada`, etc.).
4. No hay protección para impedir modificar una requisa finalizada.
5. No hay subida reanudable ni verificación de hash en servidor.
6. No hay telemetría segura, trazas correlacionadas o códigos de error estables.

### P2 — arquitectura, responsive y mantenibilidad

1. La UI contiene estado, orquestación nativa, IO, navegación y presentación en las mismas clases.
2. Hay archivos de widgets heredados de 500 a 1.300 líneas sin relación clara con el producto actual.
3. `core` depende de `presentation` en al menos un helper y `domain/menu.dart` depende de rutas de presentación, rompiendo la dirección de dependencias.
4. El responsive actual usa `OrientationBuilder`, `DeviceInfo.isMobile/isTablet`, `.w/.h/.sp/.sw/.sh` y porcentajes de altura para fuentes. Esto contradice el diseño por espacio disponible y genera tipografía más pequeña en tablet.
5. `RESPONSIVE_GUIDE.md` no coincide con el código: varios valores documentados de fuente/botón son diferentes de los tokens reales.
6. `android.hardware.usb.host` está declarado `required=true`; esto impide distribuir el módulo de gestión de requisas a Android sin OTG. Conviene separar capacidad de adquisición de capacidad de gestión o marcar la feature como opcional y bloquear solo la acción.

### P2 — validación y toolchain

- `pubspec.yaml` exige Dart `^3.9.0` y Flutter `^3.35.0`.
- El entorno activo durante la auditoría tiene Dart 3.6.0 y Flutter 3.27.1.
- `flutter pub get` y `flutter analyze` no pudieron ejecutarse por esa incompatibilidad.
- `flutter test` informó que no existen archivos terminados en `_test.dart`.
- No hay configuración FVM/mise versionada que instale o seleccione el SDK requerido.

Esto debe resolverse fijando una única versión de Flutter en CI y desarrollo antes de refactorizar.

## Archivos creados/modificados recientemente

El worktree estaba limpio para el código del producto al iniciar la revisión; solo `.agents/` y `skills-lock.json` aparecían sin seguimiento. El historial reciente muestra:

- 9–16 de julio: creación de USB/ADB, autenticación, streams, scrcpy, decoder, control y páginas de laboratorio.
- 23–24 de julio: login, started, tokens responsive y `RESPONSIVE_GUIDE.md`.
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

ReplayKit permite que **el propio equipo** grabe o transmita su pantalla, y los selectores PhotoKit/Document Picker permiten que el usuario elija fotos, videos o documentos. Multipeer Connectivity permite enviar mensajes, streams y recursos entre apps cercanas.

Para captura por cable, Apple documenta que QuickTime en macOS puede elegir un iPhone/iPad conectado como fuente y guardar el video. La confianza requiere desbloquear el dispositivo y aceptar “Confiar”. Esto respalda una arquitectura con estación Mac, no una implementación USB equivalente dentro de otro iPhone/Android.

Conclusión de ingeniería: la ausencia de una API pública tipo ADB/scrcpy y el sandbox de iOS hacen que el control remoto general por cable desde otra app móvil sea **no viable**. Esta conclusión es una inferencia basada en los frameworks públicos disponibles, no una afirmación sobre herramientas forenses propietarias.

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
- [NIST SP 800-101 Rev. 1 — Mobile Device Forensics](https://csrc.nist.gov/pubs/sp/800/101/r1/final)
