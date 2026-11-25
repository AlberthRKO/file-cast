# Adaptaciones de File Cast al visor local

Base: `offline_document_viewer` 0.1.0 (licencia MIT). Se conserva `LICENSE` y
`THIRD_PARTY_NOTICES.md`, junto con los avisos de motores y fuentes en
`assets/licenses/`.

- `text.js`: DOC, PPT y RTF se navegan en secciones de texto; el paquete
  publicado contaba párrafos como páginas pero buscaba encabezados al navegar.
- `pptx.js`: los botones y el desplazamiento notifican la diapositiva visible.
- `xlsx-render.js` y `xlsx.js`: las hojas se preparan al seleccionarlas y se
  muestran en ventanas de 120 filas por 16 columnas, con controles para
  recorrer todo el rango. El límite anterior de 3000 filas y 200 columnas
  dejaba contenido inaccesible. Se conservan estilos por celda, fila y columna
  y el estilo predeterminado. También se aplican los colores de encabezados y
  franjas alternas de estilos de tabla OOXML personalizados (`dxfs`), como los
  de la hoja `FiscaliaTarija` en `EtiquetadoTarija.xlsx`. Las imágenes PNG/JPEG,
  GIF y WebP ancladas a una celda se incluyen en la ventana visible; si el
  archivo exportó un logo diminuto dentro de una celda combinada, se ajusta
  al área combinada. Las hojas demasiado anchas se desplazan horizontalmente
  para mantener legible el texto.
- `xlsx.html` y `sheet.css`: controles de rango para hojas extensas.
- Cascarones HTML: favicon local para evitar solicitudes implícitas.
- `workspace.dart`: revisión de caché 14 para regenerar las copias al usar
  los scripts corregidos.

La fidelidad de un XLSX sigue dependiendo de los estilos que el motor puede
interpretar; una regla de formato condicional o un dibujo no anclado a una
sola celda puede requerir un ajuste específico. DOC y PPT binarios son lectura de
texto: las secciones no equivalen a las páginas o diapositivas originales.
