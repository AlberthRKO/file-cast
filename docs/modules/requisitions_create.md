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
    └── requisition_location_picker.dart
```

La búsqueda usa `searchfield` sin recrear el controlador al recibir resultados. El capturador usa `flutter_map` con `latlong2`, manteniendo el pin centrado y desplazable como en el módulo de Agenda.

La lista mantiene el launcher visual del FAB porque pertenece a `requisitions/list`; el formulario real queda aislado en `requisitions/create`.

## Flujo

1. El FAB o la acción amplia abre directamente el bottom sheet, sin preseleccionar visualmente una modalidad.
2. El operador elige `CUD existente` o `Sin CUD - Registrar persona`; la opción activa muestra un check.
3. Al seleccionar un resultado, el campo de búsqueda se reemplaza por su tarjeta resumen y permite cambiar la selección.
4. En modo CUD, el ViewModel busca contra `POST /caso/casos/list` con el payload acordado.
5. En modo persona, el ViewModel busca contra `POST /supr/persona/detalle/segip` por CI.
6. El operador confirma fecha/hora y abre el bottom sheet de captura para ajustar coordenadas y dirección. Al confirmar, el formulario muestra una tarjeta de ubicación y permite editarla.
7. `createDraft` simula el registro, emite `requisitionId/sessionId`, cierra el sheet una sola vez y hace `push` a conexión de dispositivo; volver conserva el listado/home.

## Reglas de arquitectura

- La View renderiza estado y emite intenciones.
- El ViewModel valida campos, controla busquedas con debounce y expone un snapshot inmutable.
- CUD y persona siguen el mismo patrón: `SearchField` muestra resultados y una tarjeta seleccionada los reemplaza hasta que se use su botón `X`.
- El repositorio crea los modelos de dominio y contiene el fallback de laboratorio.
- El servicio es el unico que conoce los endpoints HTTP.
- La navegacion se mantiene en `go_router`; el ViewModel no usa `BuildContext`.

## Responsive

- Compact/altura menor a 480: formulario a ancho completo con launcher por FAB y contenido desplazable.
- Medium/expanded/large: formulario centrado y limitado a `AppSize.formMaxWidth`.
- Las subsecciones usan `LayoutBuilder` para cambiar entre filas y columnas segun el ancho local.
- No se agregaron helpers responsive paralelos ni paquetes de escalado.

## Deuda pendiente

- El mapa ya usa tiles de OpenStreetMap y pin centrado; aún falta conectar GPS nativo (`geolocator`) y permisos de plataforma.
- El endpoint de persona disponible busca por CI; busqueda por nombre requiere contrato backend adicional.
- El registro final aun es simulado. Debe cambiar a API real, outbox offline y almacenamiento cifrado cuando se implemente la capa probatoria.
- El fallback de laboratorio debe retirarse o condicionarse por flavor cuando exista backend estable.
- No se uso Freezed para esta vertical porque las reglas reservan generadores al propietario; el estado se implemento manualmente con `copyWith`.
