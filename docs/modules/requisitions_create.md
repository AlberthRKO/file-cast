# Modulo Crear Requisa

## Alcance actual

El flujo de crear requisa vive bajo `lib/ui/features/requisitions/create/` y se abre desde el listado de requisas.

El acceso principal usa un `showModalBottomSheet` desde el listado. También se conserva la ruta declarativa para deep links:

```text
/requisitions/new?mode=cud
/requisitions/new?mode=person
```

Al registrar correctamente, la vista navega a:

```text
/requisitions/:requisitionId/acquisitions/:sessionId/connect
```

## Estructura

```text
lib/domain/models/requisition_creation.dart
lib/domain/repositories/requisition_creation_repository.dart
lib/data/models/requisition_creation_dto.dart
lib/data/services/requisition_creation_service.dart
lib/data/repositories/requisition_creation_repository_impl.dart
lib/ui/features/requisitions/create/
├── view_models/
│   ├── create_requisition_state.dart
│   └── create_requisition_view_model.dart
├── views/
│   └── create_requisition_view.dart
└── widgets/
    ├── create_requisition_form.dart
    └── requisition_location_map.dart
```

La búsqueda CUD presenta resultados en una lista dentro del formulario y evita el overlay de `searchfield`, que podía intentar retirar una entrada dos veces al perder el foco. Las tarjetas muestran CUD, puntaje, tipo, estado, etapa, división, ubicación, delito y plazo; no exponen los nombres de sujetos ni funcionarios. La selección conserva el mismo resumen, usa el color de fondo del scaffold y no dibuja borde. La selección de persona muestra el nombre en mayúsculas.

El mapa usa `flutter_map` con `latlong2` dentro de Datos del procedimiento. Inicia en `-19.0477918,-65.2597374`, conserva el pin fijo al centro y actualiza las coordenadas al desplazar el mapa. Los controles permiten acercar, alejar, alternar mapa satelital y solicitar/reenfocar la ubicación actual. La ubicación GPS y su marcador pulsante aparecen tras conceder el permiso. Latitud, longitud y referencia/dirección permanecen editables en el formulario.

La lista mantiene el launcher visual del FAB porque pertenece a `requisitions/list`; el formulario real queda aislado en `requisitions/create`.

## Flujo

1. El FAB o la acción amplia abre directamente el bottom sheet, sin preseleccionar visualmente una modalidad.
2. El operador elige `CUD existente` o `Sin CUD - Registrar persona`; la opción activa muestra un check.
3. Al seleccionar un resultado, el campo de búsqueda se reemplaza por su tarjeta resumen y permite cambiar la selección.
4. En modo CUD, el ViewModel busca contra `POST /api/v1/file-cast/casos/list` con el payload acordado.
5. En modo persona, el ViewModel busca contra `POST /api/v1/file-cast/persona/buscar` por CI.
6. El operador confirma fecha/hora, referencia/dirección y ubicación desde el formulario, sin abrir un modal de captura.
7. `createDraft` envía la requisa al endpoint remoto, emite el `requisitionId` devuelto por el backend, cierra el sheet una sola vez y abre el detalle de la requisa.

## Reglas de arquitectura

- La View renderiza estado y emite intenciones.
- El ViewModel valida campos, controla busquedas con debounce y expone un snapshot inmutable.
- La búsqueda se confirma con el botón o la acción del teclado; las sugerencias CUD aparecen inline mientras el campo conserva el foco y una lista acotada permite desplazarlas.
- La tarjeta seleccionada reemplaza las sugerencias hasta que se use su botón `X`.
- El repositorio crea los modelos de dominio y contiene el fallback de laboratorio.
- El servicio es el unico que conoce los endpoints HTTP.
- La navegacion se mantiene en `go_router`; el ViewModel no usa `BuildContext`.

## Responsive

- Compact/altura menor a 480: formulario a ancho completo con launcher por FAB y contenido desplazable.
- Medium/expanded/large: formulario centrado y limitado a `AppSize.formMaxWidth`.
- Las subsecciones usan `LayoutBuilder` para cambiar entre filas y columnas segun el ancho local.
- No se agregaron helpers responsive paralelos ni paquetes de escalado.

## Deuda pendiente

- El mapa y el permiso de GPS están conectados; las teselas requieren conectividad y la captura offline real de la requisa sigue pendiente.
- El endpoint de persona disponible busca por CI; busqueda por nombre requiere contrato backend adicional.
- La creación remota está conectada; crear/recuperar requisas offline todavía requiere outbox y almacenamiento local.
- El fallback de laboratorio debe retirarse o condicionarse por flavor cuando exista backend estable.
- No se uso Freezed para esta vertical porque las reglas reservan generadores al propietario; el estado se implemento manualmente con `copyWith`.
