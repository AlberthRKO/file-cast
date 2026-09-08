# Módulo Detalle de Requisa

## Flujo actual

`/requisitions/:requisitionId` muestra el caso y las evidencias en una única vista continua. El card del caso reutiliza el mismo contrato visual responsive de `CardCasoPenal` usado al crear una requisa. Los datos son mocks persistentes en memoria durante la sesión.

Las evidencias se agrupan en **Imágenes**, **Videos** y **Archivos**. Archivos incluye documentos, audios y formatos adicionales. Antes de los listados se muestran cards de carpeta con cantidad y peso acumulado por categoría. Cada sección presenta como máximo cinco elementos y ofrece **Ver todo**, que abre un `ModalBottomSheet` responsive con el listado completo.

Los `ModalBottomSheet` del detalle comparten el lenguaje del formulario de creación: fondo `Theme.cardColor`, encabezado con icono SVG, título, subtítulo y botón de cierre. Los archivos y acciones usan cards horizontales compactos para evitar espacios vacíos.

El card del caso está integrado al encabezado bajo el `AppBar`, dentro de una superficie `cardColor` con radios inferiores. Los cards de resumen, evidencias, estados vacíos y acciones no usan borde: conservan la misma sombra suave del card de caso.

- El botón flotante **+** abre un `ModalBottomSheet` con las tres acciones de adquisición.
- **Captura de pantalla:** abre la conexión Android asociada a `requisitionId` y `sessionId`.
- **Transferencia de archivos:** abre la conexión con destino transferencia y continúa en `/requisitions/:requisitionId/acquisitions/:sessionId/transfer`.
- **Importar archivos:** usa el selector del sistema, clasifica imágenes, videos, audios, documentos y otros formatos, y agrega una evidencia simulada a la sección correspondiente.

## Estructura

```text
lib/domain/models/requisition_detail.dart
lib/domain/repositories/requisition_detail_repository.dart
lib/data/services/evidence_picker_service.dart
lib/data/repositories/in_memory_requisition_detail_repository.dart
lib/ui/features/requisitions/detail/
├── view_models/requisition_detail_view_model.dart
└── views/
    └── requisition_detail_view.dart

lib/ui/features/acquisition/transfer/
├── view_models/file_transfer_view_model.dart
├── views/file_transfer_view.dart
└── widgets/file_transfer_widgets.dart
```

## Límite iOS

En iOS/iPadOS se omite la comprobación ADB/OTG, porque el canal Android no existe. La pantalla de conexión informa la limitación y devuelve al detalle; importar archivos permanece disponible mediante los selectores del sistema.

## Deuda

- Las evidencias son mocks: no hay almacenamiento, hash, cadena de custodia ni sincronización.
- Transferencia ADB desde almacenamiento compartido está implementada como vertical local; falta validación física, persistencia probatoria y backend.
- ADB/scrcpy conserva alcance Android; iOS requiere app compañera o puente macOS.
