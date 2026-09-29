# Requisitos de hardware y matriz de compatibilidad

Fecha inicial: 27 de agosto de 2026
Actualización de estrategia iPhone: 10 de septiembre de 2026

Este documento distingue el **dispositivo inspector** —donde corre File Cast— del **dispositivo objetivo** —del que se adquiere información—. “Compatible con equipos nuevos y antiguos” significa mantener una matriz explícita y validada, no garantizar cualquier combinación de teléfono, cable y sistema operativo.

## Resumen de modos

| Modo | Inspector | Objetivo | Transporte | Mirror | Control | Archivos |
|---|---|---|---|---|---|---|
| A. Android directo | Android teléfono/tablet | Android 5.0+ | USB OTG/host + ADB | Sí | Sí, sujeto a fabricante | Shared storage accesible/selección |
| B. Mirror iPhone | Android/tablet con UVC | iPhone Lightning/USB-C | Salida de video -> HDMI -> UVC | Sí, solo imagen/audio | No | No por el mismo enlace |
| C. Archivos iPhone experimental | Android USB Host | iPhone/iPad desbloqueado y confiado | USB OTG + usbmux/lockdownd/AFC | No | No | Solo ubicaciones publicadas por iOS |
| D. Backup lógico iPhone futuro | Android USB Host | iPhone/iPad desbloqueado y confiado | USB + MobileBackup2 | No | No | Backup lógico, no filesystem físico |

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

La estrategia vigente evita app compañera y computadora intermedia. Usa un
inspector Android homologado y dos conexiones separadas: HDMI/UVC para mirror y
USB de datos para la futura adquisición AFC. Consultar
[IOS_USB_LIBIMOBILEDEVICE_PLAN.md](IOS_USB_LIBIMOBILEDEVICE_PLAN.md).

### Kit de mirror

Para Lightning:

- Apple Lightning Digital AV Adapter original;
- cable HDMI corto certificado;
- capturadora HDMI -> UVC homologada;
- cable de salida USB-C de la capturadora hacia el inspector;
- hub USB-C/OTG alimentado si la matriz confirma que mantiene UVC estable.

Para USB-C:

- adaptador USB-C -> HDMI o cable activo compatible con salida de video;
- cable HDMI corto certificado;
- capturadora HDMI -> UVC homologada;
- cable USB-C hacia el inspector.

Una capturadora USB-C a USB-C que reciba DisplayPort puede reducir adaptadores
en iPhone USB-C, pero no reemplaza el Digital AV Adapter en Lightning. El canal
solo transporta imagen/audio y puede mostrar negro ante contenido protegido.

### Kit de transferencia de archivos experimental

- inspector Android con USB Host/OTG real;
- cable Lightning de datos original o certificado MFi;
- cable USB-C de datos certificado para iPhone/iPad USB-C;
- adaptador USB-C OTG a USB-A cuando el cable lo requiera;
- hub USB-C alimentado para probar estabilidad y energía;
- almacenamiento privado suficiente y SSD cifrado para exportación controlada.

El target debe desbloquearse y aceptar “Confiar”. Este enlace no promete todas
las carpetas: AFC y House Arrest exponen únicamente ubicaciones que iOS permita.
La app compañera y Mac Bridge quedan descartados como flujo principal por
decisión de producto, aunque permanecen como referencias técnicas históricas.

No se asumirá mirror y transferencia simultáneos por el único puerto del iPhone.
El procedimiento inicial cambiará del adaptador de video al cable USB de datos.
MHL no participa en ningún flujo iPhone.

## Captura HDMI/UVC para mirror iPhone

Es el canal de mirror seleccionado cuando el objetivo es un iPhone:

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
- 2 unidades de cada cable aprobado.
- 2 hubs PD aprobados.
- 2 SSD cifrados con inventario y custodia.
- 2 power banks PD y cargadores.
- 1 capturadora UVC aprobada para la PoC de mirror iPhone.
- 1 Apple Lightning Digital AV Adapter original.
- 1 adaptador USB-C a HDMI homologado.
- cables Lightning y USB-C de datos para la PoC AFC.
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
- [libimobiledevice oficial](https://github.com/libimobiledevice/libimobiledevice)
- [usbmuxd oficial](https://github.com/libimobiledevice/usbmuxd)
- [libusb en Android](https://github.com/libusb/libusb/tree/master/android)
