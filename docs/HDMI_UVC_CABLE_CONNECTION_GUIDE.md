# Guía de conexión de cables para File Cast

Fecha: 16 de noviembre de 2026

Estado: **guía de laboratorio; conexiones pendientes de validación física**

Esta guía describe cómo conectar los dispositivos para las cuatro acciones de
File Cast:

1. **Mirror** mediante ADB/scrcpy;
2. **Transferencia de archivos**;
3. **Capturadora** mediante HDMI/UVC;
4. **Importar archivos** desde el inspector.

El docking UGREEN Revodok y el docking Vention quedan fuera de esta versión. Las
pruebas de capturadora deben comenzar con conexión directa al inspector. El hub
ORICO enlazado por el propietario se documenta como variante de laboratorio
posterior: primero con un solo objetivo y, solo tras aislar sesiones en código,
con varios objetivos.

Debe leerse junto con
[HDMI_UVC_VIDEO_CAPTURE_IMPLEMENTATION_PLAN.md](HDMI_UVC_VIDEO_CAPTURE_IMPLEMENTATION_PLAN.md),
[ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md](ANDROID_MULTI_MIRROR_USB_HUB_IMPLEMENTATION_PLAN.md),
[HARDWARE_REQUIREMENTS.md](HARDWARE_REQUIREMENTS.md) e
[IOS_USB_LIBIMOBILEDEVICE_PLAN.md](IOS_USB_LIBIMOBILEDEVICE_PLAN.md).

## Hardware de captura confirmado

La capturadora mostrada en la fotografía y en la ficha de UGREEN Bolivia tiene:

- una entrada HDMI hembra;
- salida USB de datos integrada con conector USB-C macho y adaptador USB-A;
- interfaz USB 3.0 de hasta 5 Gbps;
- entrada HDMI hasta 4K30;
- captura hasta 2K30 o 1080p60;
- video y audio;
- latencia anunciada aproximada de 130 ms;
- compatibilidad anunciada con Android e iPadOS 17 o posterior;
- incompatibilidad con iPhone 15/16 usado como terminal de captura;
- incompatibilidad con HDCP, HDR y 3D;
- **sin salida HDMI loop-out**.

La resolución real debe obtenerse de AVFoundation o de los descriptores UVC. La
ficha comercial no sustituye la negociación en runtime.

Fuente: [UGREEN Bolivia — Captura HDMI 4K30 a USB A/C 3.0](https://www.ugreen-bo.com/products/ugreen-captura-de-video-hdmi-4k-30hz-a-usb-a-c-30-2k-30hz-1080p).

## Regla general de dirección

La señal siempre fluye así:

```text
DISPOSITIVO OBJETIVO
  salida de pantalla
      ↓
ADAPTADOR DE VIDEO DEL OBJETIVO
  Lightning -> HDMI o USB-C -> HDMI
      ↓
CABLE HDMI MACHO-MACHO
      ↓
ENTRADA HDMI DE LA CAPTURADORA UGREEN
      ↓
SALIDA USB-C/USB-A UVC DE LA CAPTURADORA
      ↓
DISPOSITIVO INSPECTOR
  Android USB Host o iPad Air 4 USB-C
```

La capturadora tiene dos lados con funciones distintas:

- **HDMI hembra:** recibe la imagen del objetivo;
- **USB-C/USB-A integrado:** entrega video UVC y audio UAC al inspector.

No se debe conectar el USB de la capturadora al dispositivo objetivo.

## Escenarios de Capturadora

### C1 — Android inspector + iPhone Lightning objetivo

Hardware:

- Android inspector con USB-C y USB Host/OTG;
- iPhone Lightning objetivo;
- Apple Lightning Digital AV Adapter;
- cable HDMI macho-macho;
- capturadora UGREEN.

Conexión:

```text
iPhone Lightning objetivo
  -> Apple Lightning Digital AV Adapter
  -> cable HDMI macho-macho
  -> HDMI IN de la capturadora UGREEN
  -> USB-C integrado de la capturadora
  -> USB-C del Android inspector
```

Pasos:

1. Desbloquear el iPhone objetivo.
2. Conectar el Apple Lightning Digital AV Adapter al iPhone.
3. Conectar el HDMI macho-macho entre el adaptador Apple y la capturadora.
4. Retirar el adaptador USB-A de la capturadora para dejar visible su USB-C.
5. Conectar la capturadora directamente al USB-C del Android inspector.
6. Habilitar OTG en el Android inspector si el fabricante usa un interruptor.
7. Abrir File Cast -> **Capturadora** y aceptar permiso USB/cámara.
8. Confirmar que aparezca la pantalla de inicio del iPhone antes de probar apps.

Resultado esperado:

- preview en Android;
- captura de frame;
- inicio/detención de grabación;
- sin control táctil remoto;
- sin transferencia de archivos por ese enlace.

El Apple Lightning Digital AV Adapter admite mirroring hasta 1080p. Su puerto
Lightning adicional puede alimentar el iPhone durante la prueba, pero esa
alimentación no reemplaza el USB UVC del inspector.

### C2 — Android inspector + iPhone USB-C objetivo

Hardware:

- Android inspector USB-C con USB Host/OTG;
- iPhone USB-C objetivo;
- cable/adaptador USB-C -> HDMI con dirección USB-C source a HDMI display;
- cable HDMI macho-macho si el adaptador no termina en HDMI macho;
- capturadora UGREEN.

Conexión con cable USB-C -> HDMI macho:

```text
iPhone USB-C objetivo
  -> cable USB-C -> HDMI
  -> HDMI IN de la capturadora UGREEN
  -> USB-C integrado de la capturadora
  -> USB-C del Android inspector
```

El puerto USB-C del iPhone objetivo queda ocupado por la salida HDMI. No se debe
prometer AFC simultáneo durante esta conexión.

### C3 — Android inspector + Android USB-C objetivo

Requisito obligatorio: el Android objetivo debe soportar salida de video por
USB-C DisplayPort Alt Mode. Tener USB-C, carga rápida o USB 3 no demuestra esa
capacidad.

Conexión:

```text
Android USB-C objetivo con DP Alt Mode
  -> cable USB-C -> HDMI
  -> HDMI IN de la capturadora UGREEN
  -> USB-C integrado de la capturadora
  -> USB-C del Android inspector
```

Si el objetivo no produce señal HDMI, se debe volver a **Mirror** ADB/scrcpy. No
se intentará corregir la ausencia de DisplayPort desde software.

### C4 — iPad Air 4 inspector + iPhone Lightning objetivo

Hardware:

- iPad Air 4 USB-C con iPadOS 27;
- iPhone Lightning objetivo;
- Apple Lightning Digital AV Adapter;
- cable HDMI macho-macho;
- capturadora UGREEN.

Conexión:

```text
iPhone Lightning objetivo
  -> Apple Lightning Digital AV Adapter
  -> cable HDMI macho-macho
  -> HDMI IN de la capturadora UGREEN
  -> USB-C integrado de la capturadora
  -> USB-C del iPad Air 4 inspector
```

Pasos:

1. Conectar primero la cadena de salida del iPhone hasta HDMI IN.
2. Retirar el adaptador USB-A de la capturadora.
3. Conectar directamente el USB-C integrado al iPad Air 4.
4. Abrir File Cast -> **Capturadora**.
5. Conceder permiso de cámara; conceder micrófono solo cuando se implemente audio.
6. Seleccionar la entrada externa UVC, no la cámara frontal/trasera del iPad.
7. Desactivar el mirroring horizontal automático del preview: la entrada HDMI no
   es una cámara selfie.
8. Probar captura y grabación.

### C5 — iPad Air 4 inspector + iPhone USB-C objetivo

```text
iPhone USB-C objetivo
  -> cable USB-C -> HDMI
  -> HDMI IN de la capturadora UGREEN
  -> USB-C integrado de la capturadora
  -> USB-C del iPad Air 4 inspector
```

Los dos extremos USB-C cumplen funciones diferentes: el iPhone objetivo produce
DisplayPort/HDMI y el iPad inspector recibe UVC desde la capturadora.

### C6 — iPad Air 4 inspector + Android USB-C objetivo

```text
Android USB-C objetivo con DP Alt Mode
  -> cable USB-C -> HDMI
  -> HDMI IN de la capturadora UGREEN
  -> USB-C integrado de la capturadora
  -> USB-C del iPad Air 4 inspector
```

La limitación vuelve a estar en la salida de video del Android objetivo. El iPad
no agrega DisplayPort a un teléfono que no lo soporta.

### C7 — Inspector Android con OTG USB-A

Usar esta variante solo cuando la conexión USB-C directa no active el rol host:

```text
HDMI IN de capturadora
  -> salida USB-C integrada
  -> adaptador USB-A incluido en la propia capturadora
  -> OTG USB-C a USB-A hembra
  -> Android inspector
```

No añadir el OTG si la conexión USB-C directa ya enumera correctamente la
capturadora.

### Escenario no cubierto — Android Micro-USB objetivo por HDMI

Los cables USB-A -> Micro-USB del inventario son de datos/carga. No convierten
la pantalla en HDMI. Un Android Micro-USB objetivo requiere un adaptador MHL o
SlimPort compatible con ese modelo; muchos modelos no soportan ninguno.

## Escenarios de Mirror ADB/scrcpy

Mirror conserva el decoder, control y recorder Kotlin actuales. Solo funciona
con inspector Android y objetivo Android autorizado por ADB.

### M1 — Android inspector + Android USB-C objetivo

Conexión recomendada para forzar el rol host del inspector:

```text
Android inspector USB-C
  -> OTG USB-C a USB-A hembra
  -> cable USB-A a USB-C
  -> Android USB-C objetivo
```

Alternativa a validar:

```text
Android inspector USB-C
  -> cable USB-C a USB-C de datos
  -> Android USB-C objetivo
```

La alternativa directa solo sirve si los teléfonos negocian correctamente que
el inspector sea host.

### M2 — Android inspector + Android Micro-USB objetivo

```text
Android inspector USB-C
  -> OTG USB-C a USB-A hembra
  -> cable USB-A a Micro-USB
  -> Android Micro-USB objetivo
```

En ambos casos el objetivo debe estar desbloqueado, con USB debugging habilitado
y aceptar la clave RSA.

### M3 — Un Android objetivo mediante hub ORICO USB-C

El cable fijo/upstream USB-C del ORICO se conecta al inspector. Cada USB-A del
hub es downstream para un periférico. El puerto marcado `PD` recibe el cargador;
no es el puerto de datos del objetivo.

```text
Cargador USB-C PD homologado (opcional al primer intento)
  -> puerto PD IN del ORICO

Android inspector USB-C, en rol host
  -> USB-C upstream del hub ORICO
  -> USB-A de datos #1 del ORICO
  -> cable USB-A a USB-C con datos
  -> Android objetivo desbloqueado, USB debugging activo
```

Probar primero sin mouse, teclado, Ethernet ni otros teléfonos. Cuando ADB
funcione, conectar PD y verificar que el inspector continúa como host; algunos
teléfonos o hubs cambian roles al negociar carga.

Resultado esperado con el código actual: **un solo mirror activo**. El objetivo
puede cargar y aun así no exponer datos/ADB.

Esta conexión de un solo objetivo es parte obligatoria del plan. La
implementación debe mostrar si el teléfono fue enumerado, si contiene la
interfaz ADB `255/66/1`, si File Cast tiene permiso y en qué fase falló el
handshake. Si Android enumera ADB, File Cast debe poder corregirse para abrirlo;
si Android no enumera el teléfono, el problema permanece en cable/roles/hub y no
puede solucionarse desde la app.

### M4 — Dos Android conectados al ORICO

```text
Android inspector USB-C
  -> USB-C upstream del ORICO
     |-> USB-A datos #1 -> cable de datos -> Android objetivo A
     `-> USB-A datos #2 -> cable de datos -> Android objetivo B

Cargador USB-C PD
  -> PD IN del ORICO
```

Primero conectar y autorizar A. Después conectar B y aceptar su huella RSA sin
cerrar A. El resultado final esperado es mantener ambos previews y seleccionar
cuál recibe control. Hasta implementar el registro multisesión, el código actual
cerrará A al abrir B.

### M5 — Tres Android conectados físicamente al ORICO

```text
Android inspector USB-C
  -> USB-C upstream del ORICO
     |-> USB-A datos #1 -> cable de datos -> Android objetivo A
     |-> USB-A datos #2 -> cable de datos -> Android objetivo B
     `-> USB-A datos #3 -> cable de datos -> Android objetivo C

Cargador USB-C PD
  -> PD IN del ORICO
```

Esta topología es el objetivo físico final. **File Cast no puede mostrar tres
mirrors simultáneos hoy**, porque el plugin conserva una sola conexión ADB, un
decoder, una textura y una sesión; al conectar otro objetivo cierra el anterior.
Además, retirar cualquier USB actualmente puede cerrar la sesión ADB activa.

La implementación obligatoria progresa M1 -> M2 -> M3: primero enumerar y abrir
uno, luego mantener dos sin cerrar el primero y finalmente mantener tres. Hasta
completarla, usar M5 solo como diagnóstico de enumeración. Después de homologar
la multisesión, esta misma conexión será el procedimiento operativo.

### M6 — Hub alimentado con seis USB-A y hasta seis Android

El software no debe depender del ORICO ni de una cantidad fija de tres. Para un
hub USB-C de seis puertos de datos:

```text
Android inspector USB-C
  -> USB-C upstream del hub alimentado
     |-> USB-A #1 -> Android objetivo 1
     |-> USB-A #2 -> Android objetivo 2
     |-> USB-A #3 -> Android objetivo 3
     |-> USB-A #4 -> Android objetivo 4
     |-> USB-A #5 -> Android objetivo 5
     `-> USB-A #6 -> Android objetivo 6

Cargador USB-C PD homologado
  -> PD IN del hub
```

Se prueba progresivamente 1, 2, 3, 4, 5 y 6. File Cast enumera N candidatos y
ofrece hasta `maxConcurrentMirrors`; no contiene tres slots hardcodeados. Seis
mirrors solo se declaran compatibles cuando la combinación exacta de inspector,
hub, cargador, cables y perfil H.264 supera la matriz de estabilidad.

### Por qué un objetivo puede quedarse solo cargando

Revisar en este orden:

1. conectar el USB-C upstream del ORICO al inspector, no a un puerto PD;
2. retirar temporalmente mouse, teclado y otros USB;
3. confirmar que el cable USB-A -> USB-C tiene datos, probándolo con un PC y
   `adb devices` o una transferencia real, no solo carga;
4. desbloquear el objetivo, activar Opciones de desarrollador y Depuración USB;
5. cambiar temporalmente el modo USB del objetivo a **Transferencia de
   archivos/Android Auto** para forzar la negociación de datos;
6. revocar autorizaciones de depuración USB, reconectar y aceptar la huella RSA;
7. conceder a File Cast el permiso USB para el teléfono correcto, no para el
   hub, mouse o teclado;
8. probar cada USB-A del ORICO por separado;
9. probar primero sin PD y luego con PD, verificando que el inspector siga en
   rol host;
10. repetir la conexión directa M1. Si M1 funciona y M3 no, la incompatibilidad
    está en la combinación inspector/hub/energía; si tampoco funciona M1,
    revisar cable, ADB y configuración del objetivo.

Que el mouse y el teclado funcionen solo confirma el rol host del inspector y
los puertos HID. No confirma que el teléfono exponga su interfaz ADB.

### H1 — Capturadora UGREEN mediante el ORICO

Usar el adaptador USB-A integrado de la capturadora y un USB-A de datos del
ORICO. El HDMI del ORICO no participa: es salida de video del inspector, no
entrada.

```text
Objetivo con salida de video
  -> adaptador Lightning/USB-C a HDMI
  -> cable HDMI macho-macho
  -> HDMI IN de la capturadora UGREEN
  -> USB-C integrado + adaptador USB-A de la capturadora
  -> USB-A de datos del ORICO
  -> USB-C upstream del ORICO
  -> Android inspector

Cargador USB-C PD
  -> PD IN del ORICO
```

Esta variante se prueba solo después de que la misma capturadora funcione
directamente. Comenzar en 1080p30; todos los puertos comparten el enlace
upstream, energía y recursos del inspector.

### H2 — Capturadora y ADB conectados al mismo ORICO

Físicamente se puede intentar UGREEN en un USB-A y un Android objetivo ADB en
otro, pero no es un escenario habilitado por el plan inicial. Primero deben
separarse receivers y sesiones por `deviceId`; con el código actual, retirar uno
de los periféricos puede desconectar el otro.

## Escenarios de Transferencia de archivos

### T1 — Android objetivo -> Android inspector

Usa exactamente los cables de M1 o M2. La diferencia está en la acción elegida
en File Cast:

```text
File Cast -> Transferencia de archivos
  -> ADB Sync LIST/STAT/RECV
  -> almacenamiento privado del inspector
```

No conectar la capturadora para este flujo.

### T2 — iPhone Lightning objetivo -> Android inspector, futuro AFC

```text
Android inspector USB-C
  -> OTG USB-C a USB-A hembra
  -> cable USB-A a Lightning certificado MFi
  -> iPhone Lightning objetivo
```

El iPhone deberá estar desbloqueado y aceptar **Confiar**. Esta ruta sigue siendo
una PoC futura de `libimobiledevice`; no está implementada.

### T3 — iPhone USB-C objetivo -> Android inspector, futuro AFC

Primera variante:

```text
Android inspector USB-C
  -> cable USB-C a USB-C de datos
  -> iPhone USB-C objetivo
```

Si no se negocia el host:

```text
Android inspector USB-C
  -> OTG USB-C a USB-A hembra
  -> cable USB-A a USB-C
  -> iPhone USB-C objetivo
```

Esta ruta tampoco está implementada todavía.

### Transferencia desde un objetivo hacia iPad inspector

No forma parte del alcance actual. La capturadora UVC solo entrega video/audio;
no expone archivos del objetivo. File Cast en iPad conserva **Importar archivos**
para elementos accesibles localmente mediante los selectores del sistema.

## Importar archivos

No requiere cable hacia otro dispositivo:

```text
File Cast en Android o iPad
  -> Importar archivos
  -> selector del sistema
  -> preview de confirmación
  -> cifrado FCE + outbox
```

Si un archivo está en una memoria externa que el sistema expone al selector,
esa disponibilidad pertenece al sistema operativo y no a la capturadora.

## Disponibilidad de las cuatro opciones

Las cuatro opciones deben conservarse como acciones distintas. La UI publica
capacidad real y explica por qué una acción no está disponible.

| Inspector | Mirror | Transferencia | Capturadora | Importar |
|---|---|---|---|---|
| Android | Sí; N Android ADB hasta capacidad homologada, ORICO 1–3 y hub ampliado 4–6 | Sí, un objetivo Android seleccionado; iPhone futuro | Sí, objetivo Android/iPhone con HDMI | Sí |
| iPad Air 4 | No ADB/scrcpy | No desde otro teléfono | Sí, objetivo Android/iPhone con HDMI | Sí |
| iPhone | No | No desde otro teléfono | No UVC genérico | Sí |

En iPad, las tarjetas Mirror y Transferencia pueden permanecer visibles con una
explicación de capacidad no disponible. No deben iniciar canales Android ni
simular compatibilidad.

## Orden recomendado para conectar Capturadora

1. Cerrar cualquier sesión Mirror o Transferencia activa.
2. Desbloquear el objetivo.
3. Conectar el adaptador de video al objetivo.
4. Conectar el HDMI al adaptador y al HDMI IN de la capturadora.
5. Conectar el USB integrado de la capturadora al inspector.
6. Abrir File Cast y elegir **Capturadora**.
7. Conceder permisos.
8. Confirmar el formato negociado.
9. Esperar imagen estable antes de capturar o grabar.

Para desconectar:

1. detener y guardar la grabación;
2. esperar confirmación de archivo válido;
3. cerrar la sesión Capturadora en File Cast;
4. retirar el USB del inspector;
5. retirar HDMI y el adaptador del objetivo.

## Prueba manual inicial

Ejecutar primero en `1080p30 SDR`, aunque la capturadora anuncie más:

1. abrir la pantalla de inicio del objetivo;
2. verificar que no exista espejo horizontal;
3. cambiar entre portrait y landscape;
4. capturar 10 frames;
5. grabar 30 segundos, 5 minutos y 30 minutos;
6. reproducir cada MP4 y revisar inicio, final, duración y orientación;
7. desconectar HDMI sin retirar USB y verificar `noSignal`;
8. reconectar HDMI y verificar recuperación;
9. retirar USB durante una grabación y confirmar eliminación o cierre seguro del
   `.part`;
10. repetir 20 ciclos de conexión/desconexión.

Después habilitar `1080p60` y `2K30` por separado. No asumir que ambos modos
tienen la misma estabilidad, latencia o formato de pixel.

## Diagnóstico de “sin señal”

Revisar en este orden:

1. el cable entra al único HDMI de la capturadora;
2. el teléfono objetivo realmente soporta salida HDMI;
3. el adaptador USB-C -> HDMI es direccional y compatible;
4. el iPhone Lightning usa un Digital AV Adapter alimentado/compatible;
5. el objetivo muestra la pantalla de inicio, no contenido HDCP;
6. el inspector detecta la capturadora como entrada externa;
7. Android otorgó permiso USB/cámara o iPad otorgó permiso de cámara;
8. el modo se degradó a 1080p30;
9. se reconectó primero HDMI y después USB;
10. no se está intentando usar un cable de datos como adaptador de video.

## Límites operativos

- La capturadora no controla el objetivo.
- La capturadora no transfiere archivos.
- No existe loop-out: la app del inspector es el único monitor durante la prueba.
- HDMI/UVC puede agregar aproximadamente 130 ms o más de latencia.
- HDCP/HDR/3D no están soportados por el modelo confirmado.
- Capturadora y ADB/AFC son sesiones separadas; se cambia físicamente el cable.
- En el baseline directo, el inspector trabaja desde batería; el ORICO con PD
  se homologa después y debe conservar el rol host.
- Un hub permite conectar periféricos, pero no crea soporte multisesión dentro
  de File Cast.
- El hash corresponde al archivo capturado por File Cast, no al framebuffer del
  objetivo.

## Evidencia de cada prueba

Registrar:

- inspector, objetivo y versiones de OS;
- IDs de inventario de adaptador y cables;
- identificación UVC/UAC de la capturadora;
- formato solicitado y formato real;
- timestamps de conexión, primer frame, captura y grabación;
- frames descartados, pérdida de señal y errores;
- tamaño, duración y SHA-256 de cada archivo;
- resultado visual y observaciones de color/rotación/latencia.

## Fuentes

- [UGREEN Bolivia — Captura HDMI 4K30 a USB A/C 3.0](https://www.ugreen-bo.com/products/ugreen-captura-de-video-hdmi-4k-30hz-a-usb-a-c-30-2k-30hz-1080p)
- [Apple WWDC23 — External cameras in iPadOS](https://developer.apple.com/videos/play/wwdc2023/10106/)
- [Apple — iPad Air 4 technical specifications](https://support.apple.com/111905)
- [Apple — USB-C on iPad](https://support.apple.com/108894)
- [Apple — Lightning Digital AV Adapter](https://www.apple.com/shop/product/mw2p3am/a/lightning-digital-av-adapter)
- [AOSP — External USB cameras](https://source.android.com/docs/core/camera/external-usb-cameras)
- [Android Developers — USB host y enumeración](https://developer.android.com/develop/connectivity/usb/host)
- [ORICO aportado por el propietario — ASIN B0BYS4D3KR](https://www.amazon.com.be/-/en/ORICO-Ethernet-Docking-Station-Multiport/dp/B0BYS4D3KR)
