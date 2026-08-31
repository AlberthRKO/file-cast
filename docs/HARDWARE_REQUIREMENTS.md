# Requisitos de hardware y matriz de compatibilidad

Fecha: 27 de agosto de 2026

Este documento distingue el **dispositivo inspector** —donde corre File Cast— del **dispositivo objetivo** —del que se adquiere información—. “Compatible con equipos nuevos y antiguos” significa mantener una matriz explícita y validada, no garantizar cualquier combinación de teléfono, cable y sistema operativo.

## Resumen de modos

| Modo | Inspector | Objetivo | Transporte | Mirror | Control | Archivos |
|---|---|---|---|---|---|---|
| A. Android directo | Android teléfono/tablet | Android 5.0+ | USB OTG/host + ADB | Sí | Sí, sujeto a fabricante | Shared storage accesible/selección |
| B. iOS Companion | Android/iOS/tablet | iPhone/iPad con companion | Wi-Fi peer/local; Bluetooth para discovery | ReplayKit iniciado por usuario | No control general | PhotoKit/Document Picker |
| C. iOS Mac Bridge | Android/iOS/web + servicio | iPhone/iPad confiado | USB hacia macOS | Sí, captura autorizada | No control general | Import/backup autorizado según alcance |
| D. Video físico fallback | Android/tablet o Mac | Android/iOS con salida de video | HDMI -> capturadora UVC | Sí, solo imagen | No | No por el mismo enlace |

## Kit mínimo para Android directo

### Dispositivo inspector

Requerido:

- Android con `android.hardware.usb.host`/OTG real.
- Android 10 o posterior recomendado para el inspector; el mínimo final debe fijarse después de resolver el SDK Flutter y probar el plugin.
- USB-C con transferencia de datos. USB 3.x es preferible, aunque muchos objetivos negocian ADB a velocidad USB 2.0.
- 6 GiB RAM como mínimo operativo; 8 GiB o más recomendado para mirror + decode + grabación + UI.
- 128 GB de almacenamiento como mínimo; 256 GB o más recomendado para trabajo offline.
- Decodificador H.264 por hardware estable.
- Batería en buen estado y capacidad de carga durante sesiones largas.

Preferido para operación de campo:

- tablet de 8–13 pulgadas con 8–12 GiB RAM;
- USB-C 3.1/3.2 con DisplayPort no es necesario, pero un puerto de alta calidad mejora hubs y SSD;
- ranura microSD solo si la política permite almacenamiento removible cifrado;
- gestión empresarial, bloqueo remoto y actualizaciones controladas.

### Cables y adaptadores

Mantener unidades cortas, certificadas, probadas y etiquetadas:

- USB-C macho a USB-C macho **con datos**, idealmente con e-marker cuando corresponda.
- USB-A macho a USB-C macho.
- USB-A macho a Micro-USB.
- Adaptador USB-C OTG hembra USB-A para el inspector.
- Adaptador Micro-USB OTG para un inspector antiguo, solo si forma parte de la matriz.
- Cable Mini-USB si se atenderán Android muy antiguos que lo usen.
- Extensiones únicamente si se han probado; evitar cadenas de adaptadores.

Un cable “solo carga” no funciona. Un data blocker tampoco puede usarse para ADB porque elimina precisamente las líneas de datos.

### Energía y hubs

El inspector actúa como USB host y alimenta el bus. Para sesiones largas se recomienda:

- hub USB-C alimentado con Power Delivery y data passthrough;
- cargador USB-C PD de 45–65 W certificado;
- power bank PD de 20.000 mAh o superior para campo;
- hub con protección de sobrecorriente y fuente separada;
- medidor USB-C opcional para diagnosticar voltaje/corriente/rol, nunca como única evidencia de enlace.

La combinación `inspector -> hub PD -> cable de datos -> objetivo` debe probarse por modelo. Algunos teléfonos cambian de rol o dejan de enumerar ADB cuando el hub intenta cargar ambos lados.

### Almacenamiento

- SSD externo USB-C de 1–2 TB, cifrado y dedicado, para exportaciones/backup controlado.
- Segundo SSD para copia verificada si el procedimiento exige dos copias.
- El almacenamiento de trabajo primario debe permanecer en el sandbox cifrado de la app; no escribir evidencia directamente a medios removibles sin transacción y verificación.

Dimensionamiento aproximado de grabación H.264:

```text
4 Mbit/s  ~= 1.8 GB/hora
8 Mbit/s  ~= 3.6 GB/hora
12 Mbit/s ~= 5.4 GB/hora
20 Mbit/s ~= 9.0 GB/hora
```

Reservar, además, espacio para temporales, thumbnails, logs, uploads incompletos y margen de seguridad. La app debe impedir iniciar una grabación si no puede garantizar el umbral configurado.

## Requisitos del Android objetivo

### Mirror/control del proyecto

- Android 5.0/API 21 o posterior por el requisito de scrcpy.
- Dispositivo desbloqueado durante autorización inicial.
- Opciones de desarrollador y USB debugging activados.
- Aceptación visible de la clave RSA del inspector.
- En algunos fabricantes se requiere una opción adicional de “USB debugging (Security settings)” para inyección de entrada.
- Puerto y cable con datos en buen estado.

No se requiere root para scrcpy. No obstante, ADB shell no da acceso universal a datos privados de apps.

### Equipos anteriores a Android 5.0

El mirror scrcpy actual no los cubre. Opciones posibles, siempre separadas en la UI:

- transferencia manual/MTP/PTP si el modelo la ofrece;
- salida HDMI/MHL/SlimPort hacia capturadora;
- estación especializada autorizada;
- declarar el modelo como no compatible.

No conviene degradar todo el producto para soportar estos equipos sin una necesidad estadísticamente demostrada.

### Conectores Android antiguos

Mantener Micro-USB OTG y, si el inventario lo justifica, Mini-USB. Verificar individualmente:

- que el target enumere interfaz ADB;
- que el inspector conserve el rol host;
- estabilidad durante 30/60 minutos;
- reconexión tras aceptar RSA;
- captura, control, grabación y pull.

## Kit para iPhone/iPad

## Ruta recomendada: Mac Bridge por cable

### Estación

- MacBook/Mac mini Apple silicon con macOS aprobado por el laboratorio.
- 16 GiB RAM mínimo; 24–32 GiB recomendado si se graba, hashea y sube en paralelo.
- SSD interno de 512 GB mínimo; 1 TB o más recomendado.
- SSD externo cifrado de 1–2 TB para staging/backup.
- UPS para estación fija o batería saludable para portátil.
- cuenta operativa sin privilegios administrativos para uso diario y custodia de claves separada.

### Cables Apple

- USB-C a USB-C con datos para iPhone 15 y posteriores/otros equipos USB-C.
- USB-C a Lightning certificado para equipos Lightning.
- USB-A a Lightning certificado para estaciones/hubs antiguos.
- 30-pin Apple solo si una matriz legacy real lo exige; no asumir que QuickTime/captura moderna funcionará con modelos que quedaron en versiones antiguas de iOS.
- hub USB-C alimentado si se conectan SSD y dispositivo simultáneamente.

El target debe desbloquearse y aceptar “Confiar”. El procedimiento debe registrar qué estación fue confiada y revocar/restablecer la relación cuando corresponda.

### Alcance del Mac Bridge

Apple documenta que QuickTime puede capturar lo mostrado por un iPhone/iPad conectado y guardarlo como video. El servicio productivo puede usar una integración macOS equivalente y autorizada, pero debe validarse en cada versión de macOS/iOS y no basarse en automatización frágil de la UI de QuickTime.

No comprar hardware asumiendo que este camino permitirá inyectar touch/control remoto. El objetivo es captura y transferencia autorizada.

## Ruta iOS Companion

Hardware:

- iPhone/iPad objetivo dentro de la versión mínima que finalmente soporte el companion.
- inspector Android/iOS/tablet con Wi-Fi y Bluetooth.
- router Wi-Fi 6/6E de campo, aislado de internet si la operación es offline.
- power bank/cargadores para ambos equipos.
- QR impreso o mostrado por el inspector para emparejamiento de sesión.

Multipeer Connectivity puede usar Wi-Fi local/peer-to-peer y Bluetooth para conectividad cercana. Aun así, la matriz debe medir rendimiento real; para video estable es preferible una red Wi-Fi dedicada y limpia.

La persona en el target debe:

- abrir la app compañera;
- aceptar el emparejamiento;
- seleccionar archivos con los controles del sistema;
- iniciar ReplayKit desde el selector de broadcast cuando se requiera pantalla.

## Captura HDMI/UVC como fallback

Útil cuando solo se necesita evidencia visual y el USB de datos no es viable:

- adaptador de salida de video original/certificado adecuado al target;
- cable HDMI corto;
- capturadora HDMI -> UVC que entregue 1080p30/60 estable;
- inspector Android con USB host y soporte UVC probado, o Mac;
- hub alimentado si la capturadora consume demasiado.

Limitaciones:

- no transfiere archivos ni controla el target;
- puede introducir escalado, barras, latencia y cambios de color;
- contenido protegido puede aparecer negro;
- el hash corresponde al archivo capturado, no a un framebuffer original del target;
- requiere calibración y documentación del pipeline completo.

## Herramientas forenses especializadas

Si el requisito cambia a extracción de sistema de archivos, backup avanzado, equipo bloqueado o datos privados de apps, una app propia basada en APIs públicas no cubre el alcance. Se necesita un proceso de compra/validación separado de herramientas forenses comerciales o institucionales, con:

- soporte contractual de modelos/versiones;
- formación y licencias;
- validación independiente;
- exportación con logs/manifiestos;
- procedimiento legal y de cadena de custodia.

Estas herramientas no deben mezclarse silenciosamente con el flujo “mirror y archivos seleccionados”; son otro método de adquisición.

## Matriz mínima de laboratorio

### Inspectores Android

Probar al menos:

- teléfono compacto, 6 GiB RAM, Android mínimo soportado;
- teléfono moderno, 8+ GiB RAM, USB-C;
- tablet 8–9 pulgadas;
- tablet 10–13 pulgadas;
- al menos un dispositivo sin OTG para validar el bloqueo por capacidades.

### Objetivos Android

- Android 5/6 con Micro-USB si todavía está en alcance;
- Android 8/9;
- Android 10/11;
- Android 12/13;
- Android 14;
- Android 15/16;
- Samsung, Motorola/Lenovo, Google Pixel y al menos un fabricante con restricciones de control;
- resoluciones 720p, 1080p, alta densidad y tablet;
- rotación durante mirror/grabación.

### Objetivos Apple

- iPhone Lightning antiguo dentro de soporte;
- iPhone Lightning reciente;
- iPhone USB-C;
- iPad Lightning si aplica;
- iPad USB-C;
- versión iOS/iPadOS mínima, intermedia y actual aprobada;
- pruebas con dispositivo recién confiado, ya confiado y confianza revocada.

## Prueba de aceptación de cada accesorio

Etiquetar cada cable/hub/capturadora con ID de inventario y ejecutar:

1. enumeración 20 veces;
2. mirror continuo 60 minutos;
3. 100 capturas comparadas;
4. grabación de 30 minutos y validación del contenedor;
5. transferencia de 1 MB, 1 GB y lote de archivos pequeños;
6. desconexión/reconexión durante cada operación;
7. operación con carga simultánea;
8. verificación SHA-256 antes/después;
9. revisión visual de frames perdidos, color, rotación y touch;
10. registro de temperatura y throttling del inspector.

Un accesorio solo pasa a operación si el resultado es repetible con la combinación exacta de inspector, OS y target.

## Inventario operativo recomendado

- 2 inspectores Android homologados.
- 1 tablet Android homologada para el layout de dos paneles.
- 1 Mac Bridge homologada si iOS entra al alcance.
- 2 unidades de cada cable aprobado.
- 2 hubs PD aprobados.
- 2 SSD cifrados con inventario y custodia.
- 2 power banks PD y cargadores.
- 1 capturadora UVC aprobada si se adopta el fallback.
- etiquetas inviolables, bolsas, adaptadores y kit de limpieza de puertos.

## Fuentes verificadas

- [Android USB host](https://developer.android.com/develop/connectivity/usb/host)
- [Android USB host/accessory overview](https://developer.android.com/develop/connectivity/usb)
- [scrcpy oficial y requisitos](https://github.com/Genymobile/scrcpy/)
- [Apple: captura de iPhone/iPad conectado en QuickTime](https://support.apple.com/es-es/guide/quicktime-player/qtp356b55534/mac)
- [Apple: alerta Confiar en esta computadora](https://support.apple.com/es-lamr/109054)
- [Apple ReplayKit](https://developer.apple.com/documentation/replaykit)
- [Apple Multipeer Connectivity](https://developer.apple.com/documentation/MultipeerConnectivity)
- [Apple External Accessory/MFi](https://developer.apple.com/documentation/externalaccessory)
