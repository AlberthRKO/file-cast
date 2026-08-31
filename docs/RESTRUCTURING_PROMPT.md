# Prompt para reestructurar las vistas

Copiar el siguiente prompt en una nueva sesión que trabaje sobre este mismo repositorio. Se recomienda ejecutar una fase por sesión y revisar el diff antes de continuar.

Para migrar únicamente una pantalla o un archivo, usar [SINGLE_VIEW_REFACTOR_PROMPT.md](SINGLE_VIEW_REFACTOR_PROMPT.md).

## Prompt maestro

```text
Trabaja en el repositorio File Cast y realiza una migración incremental de sus vistas Flutter.

Antes de cambiar código:

1. Lee completamente el AGENTS.md de la raíz.
2. Lee completamente:
   - docs/PROJECT_STATUS_AND_FEASIBILITY.md
   - docs/IMPLEMENTATION_PLAN.md
   - docs/ARCHITECTURE_GUIDE.md
   - docs/RESPONSIVE_GUIDE.md
   - docs/ROUTING_GUIDE.md
3. Usa obligatoriamente y lee completamente estas skills:
   - $flutter-apply-architecture-best-practices
   - $flutter-build-responsive-layout
   - $flutter-setup-declarative-routing
4. Inspecciona git status y preserva todos los cambios existentes.

Objetivo general:

- Reemplazar progresivamente la arquitectura responsive heredada por infraestructura nueva en lib/ui/core/adaptive/.
- No reutilizar DeviceInfo, Responsive, flutter_screenutil, .sw/.sh/.sp/.w/.h/.r ni OrientationBuilder en archivos nuevos o migrados.
- Migrar nuevas vistas a lib/ui/features/ con MVVM, estados inmutables, repositorios y servicios por constructor.
- Usar Freezed para modelos, DTO y estados nuevos; crear fuentes anotadas sin ejecutar ni editar los generados.
- Centralizar navegación en lib/ui/core/navigation/ usando MaterialApp.router y go_router.
- Reemplazar Navigator.push/MaterialPageRoute y Map<String,dynamic> al migrar cada feature.
- Mantener identidad visual, textos y comportamiento funcional existentes salvo que la documentación defina un cambio.
- No tocar USB/ADB/scrcpy durante tareas de UI, excepto cuando se migre expresamente acquisition.

Restricción de validación del propietario:

- No ejecutes flutter test.
- No ejecutes flutter analyze.
- No ejecutes flutter run ni flutter build.
- No compiles Android/iOS.
- No ejecutes generadores de código.
- No agregues tests salvo solicitud explícita.
- Revisa el cambio únicamente por inspección y deja claro que la validación queda pendiente del propietario.

Método de trabajo:

- Trabaja solo en la fase indicada abajo.
- No hagas un rename masivo de presentation/.
- Crea la nueva versión de una feature, cambia su ruta y elimina únicamente archivos que queden sin consumidores.
- Si hacen falta datos mock, colócalos detrás de un repositorio in-memory temporal; nunca dentro de la View.
- No elimines flutter_screenutil del pubspec hasta que no tenga consumidores.
- No cambies archivos generados manualmente.

FASE A EJECUTAR: [PEGAR AQUÍ UNA DE LAS FASES DEFINIDAS ABAJO]

Entrega:

1. Resume las decisiones arquitectónicas.
2. Lista archivos creados, modificados y retirados.
3. Indica qué lógica salió de las Views.
4. Confirma que los archivos migrados no importan responsive heredado.
5. Explica las rutas declarativas agregadas o migradas.
6. Enumera deuda pendiente y siguiente fase recomendada.
7. Confirma que no ejecutaste tests, analyze ni compilación.
```

## Fase 1 — infraestructura base existente

> La infraestructura inicial ya existe. Esta fase solo se usa para inspeccionarla o completar una pieza faltante; no debe crear un segundo sistema paralelo.

```text
Inspecciona y conserva los cimientos compartidos existentes:

- lib/ui/core/adaptive/window_size_class.dart
- lib/ui/core/adaptive/adaptive_layout.dart
- lib/ui/core/adaptive/constrained_content.dart
- tokens lógicos de spacing, radius, tamaños y ancho máximo sin BuildContext ni ScreenUtil
- lib/ui/core/navigation/app_route.dart
- lib/ui/core/navigation/app_route_error_view.dart
- lib/ui/core/navigation/app_router.dart como destino canónico

Completa únicamente una pieza que realmente falte. `MaterialApp.router` ya consume el router canónico y existen adaptadores para rutas heredadas. No migres pantallas completas en esta fase y no retires helpers heredados.
```

## Fase 2 — Started y Login

```text
Migra únicamente Started y Login a lib/ui/features/.

- Usa LayoutBuilder y las clases de ventana nuevas.
- Compact: composición vertical y scroll cuando la altura sea compacta.
- Medium+: contenido centrado o composición de dos zonas con ancho limitado.
- Login usa ViewModel para formulario/estado; no debe navegar simulando autenticación exitosa.
- Registra /started y /login en el router canónico.
- Elimina DeviceInfo, OrientationBuilder y ScreenUtil solo de los archivos migrados.
- Mantén los archivos heredados necesarios para otras pantallas.
```

## Fase 3 — listado de requisas/Home

```text
Reemplaza HomePage por la feature ui/features/requisitions/list.

- Define Requisition como modelo de dominio inmutable si todavía no existe.
- Crea contrato de RequisitionRepository y una implementación in-memory temporal para conservar los datos simulados.
- Crea RequisitionListState y RequisitionListViewModel.
- Mueve búsqueda, filtros, paginación visual y carga fuera de la View.
- Compact: cards verticales.
- Medium: cards/grid según constraints locales.
- Expanded/Large: tabla o lista densa con ancho limitado.
- Usa builders/slivers para colecciones.
- Registra /requisitions y redirige el home autenticado a esa ruta.
- No implementes backend ni modifiques USB.
```

## Fase 4 — crear y detallar requisa

```text
Migra crear requisa y detalle a ui/features/requisitions/create y detail.

- Crear: full-screen en compact/altura compacta; diálogo limitado y scrollable en medium+.
- Detalle: evidencia, resumen de conexión y acciones derivadas del estado del ViewModel.
- Agrega /requisitions/new y /requisitions/:requisitionId.
- Los IDs viajan por pathParameters, no por Map extra.
- Mantén acciones no implementadas como capacidades/estados explícitos, no como lógica falsa en la View.
```

## Fase 5 — shell, Settings y Offline

```text
Evalúa si existen al menos dos o tres destinos persistentes reales. Solo entonces crea StatefulShellRoute.indexedStack.

- Compact: NavigationBar cuando esté justificado.
- Medium/Expanded: NavigationRail.
- Login, Started, creación y mirror permanecen fuera del shell cuando corresponda.
- Migra Settings y Offline a rutas declarativas.
- No inventes secciones solamente para justificar el shell.
```

## Fase 6 — conexión y mirror

```text
Migra la UI de USB/connect/mirror detrás de AcquisitionViewModel y servicios nativos existentes, sin reescribir el protocolo ADB.

- Toda ruta incluye requisitionId y sessionId.
- Reemplaza Navigator.push/MaterialPageRoute por go_router.
- Reemplaza Map<String,dynamic> por path IDs y MirrorRouteArgs tipado para handles efímeros.
- Compact: mirror principal y controles persistentes; evidencias en tab/bottom sheet.
- Expanded con altura regular: dos paneles.
- El área táctil se calcula con constraints y aspect-fit.
- Implementa cleanup idempotente al abandonar la sesión mediante el ViewModel.
```

## Orden recomendado

Si `lib/ui/core/adaptive/` y `lib/ui/core/navigation/` están presentes, comenzar con Fase 2 o utilizar el prompt de una sola vista. Abrir una sesión por fase y no combinar Fase 3 con Fase 6.
