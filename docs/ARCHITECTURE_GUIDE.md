# Guía de arquitectura Flutter

Esta es la referencia operativa para crear y migrar features de File Cast. Complementa el plan general de [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), la UI adaptive de [RESPONSIVE_GUIDE.md](RESPONSIVE_GUIDE.md) y las rutas de [ROUTING_GUIDE.md](ROUTING_GUIDE.md).

El estado y orden real de migración se mantiene en [MIGRATION_TRACKER.md](MIGRATION_TRACKER.md). No asumir que una carpeta legacy puede retirarse solo porque una vista equivalente ya existe.

## Decisión arquitectónica

File Cast usa MVVM con repositorios y una capa de dominio opcional:

```text
View
  -> ViewModel
      -> Use Case, cuando aporta valor
          -> Repository contract
              -> Repository implementation
                  -> Service/API/DB/plugin nativo
```

El objetivo no es crear capas vacías, sino evitar que las pantallas controlen red, almacenamiento, adquisición o reglas de negocio.

## Responsabilidades

### View

- renderiza un snapshot inmutable;
- decide layout mediante constraints;
- gestiona animaciones, foco, scroll y navegación simple;
- invoca comandos del ViewModel;
- no conoce DTO de API ni servicios nativos;
- no construye datos mock ni filtra colecciones de negocio.

### ViewModel

- coordina interacciones de la pantalla;
- expone `state` inmutable y notifica cambios;
- evita operaciones duplicadas;
- convierte fallos de dominio en estados presentables;
- recibe repositorios o Use Cases por constructor;
- no usa `BuildContext`, `MediaQuery`, widgets ni `GoRouter`.

Los snapshots de estado se definen con Freezed. El agente crea únicamente el archivo fuente anotado; el propietario genera `*.freezed.dart` y `*.g.dart`.

### Use Case

Se crea cuando una acción:

- combina varios repositorios;
- aplica reglas de custodia o estados de requisa;
- requiere una transacción conceptual;
- se reutiliza en varios ViewModels.

CRUD simple puede ir del ViewModel al repositorio.

### Repository

- es la fuente de verdad de una capacidad;
- devuelve modelos de dominio, no DTO crudos;
- decide API, caché, base local, retry y sincronización;
- expone contratos en `domain/repositories` e implementaciones en `data/repositories`.

## Modelos inmutables con Freezed

- Modelos de dominio, DTO y estados de UI nuevos usan Freezed.
- Los modelos de dominio representan reglas limpias y normalmente no implementan JSON.
- Los DTO de `data/models` pueden usar `fromJson`/`toJson` con `json_serializable`.
- Los estados de ViewModel usan Freezed para `copyWith`, igualdad e inmutabilidad.
- Enums simples no necesitan Freezed.
- Nunca editar manualmente código generado.
- Por la restricción de validación, los agentes no ejecutan `build_runner`; el propietario genera los archivos después de revisar el cambio.

### Service

- envuelve una sola frontera externa;
- es stateless cuando sea posible;
- no contiene estado de UI;
- puede envolver HTTP, base local, archivos cifrados, conectividad o canales nativos.

## Estructura canónica

```text
lib/
├── data/
│   ├── models/
│   ├── repositories/
│   └── services/
├── domain/
│   ├── models/
│   ├── repositories/
│   └── use_cases/
└── ui/
    ├── core/
    │   ├── adaptive/
    │   ├── navigation/
    │   ├── theme/
    │   └── widgets/
    └── features/
        ├── auth/
        ├── requisitions/
        │   ├── list/
        │   ├── create/
        │   └── detail/
        ├── acquisition/
        ├── evidence/
        └── settings/
```

Ejemplo de una feature:

```text
ui/features/requisitions/list/
├── view_models/
│   ├── requisition_list_state.dart
│   └── requisition_list_view_model.dart
├── views/
│   └── requisition_list_view.dart
└── widgets/
    ├── requisition_card.dart
    ├── requisition_table.dart
    └── requisition_filters.dart
```

## Base organizada actualmente

La fase de organización inicial ya creó:

```text
lib/ui/core/
├── adaptive/
│   ├── adaptive.dart
│   ├── adaptive_layout.dart
│   ├── constrained_content.dart
│   └── window_size_class.dart
├── navigation/
│   ├── app_route.dart
│   ├── app_route_error_view.dart
│   ├── app_router.dart
│   └── route_args/mirror_route_args.dart
└── theme/
    └── layout_tokens.dart
```

`lib/app.dart` consume el router canónico. Los archivos de `lib/presentation/routes/` son adaptadores temporales para las vistas que todavía no se han migrado. El router nuevo todavía importa páginas de `presentation/`; cada import se sustituye cuando su feature pase a `ui/features/`.

No crear una segunda infraestructura adaptive, otro router global ni nuevos tokens paralelos.

## Estado de UI

Cada ViewModel expone un único snapshot. El estado debe representar como mínimo las variantes relevantes:

```text
initial/loading/content/empty/error/offline
```

Los flags de operaciones independientes pueden convivir dentro del snapshot, por ejemplo `isRefreshing`, `isCreating` o `isFinalizing`. Los objetos y listas expuestos son inmutables.

No dispersar el estado de una feature entre varios `setState` de widgets. El estado puramente visual y local, como una animación expandida o el foco de un campo, sí puede permanecer en la View.

ScrollController, TextEditingController, FocusNode y AnimationController pertenecen a la View y deben liberarse en `dispose`. Búsqueda, filtros, página/cursor, `hasMore`, prevención de cargas duplicadas y combinación de resultados pertenecen al ViewModel/repositorio.

Los bottom sheets y dialogs creados sobre un `Navigator` pueden quedar fuera del scope de un Provider registrado dentro de la ruta. No consultar providers profundos desde esos overlays. Pasar estado/comandos explícitos, usar el ViewModel ya inyectado como `Listenable` o crear un scope deliberado con `.value` cuando corresponda.

## Inyección de dependencias

- Registrar Services, Repository implementations, Use Cases y ViewModels en el composition root.
- Preferir inyección por constructor.
- Evitar service locators llamados desde dominio o UI profunda.
- El router puede construir una pantalla mediante un widget de scope que crea el ViewModel con dependencias ya registradas.
- El ciclo de vida del ViewModel pertenece al scope de la ruta o feature.

## Migración desde `presentation/`

`lib/presentation/` permanece temporalmente para no romper el prototipo. Una migración correcta:

1. identifica una pantalla y sus widgets realmente utilizados;
2. define modelos/contratos que falten;
3. mueve mocks detrás de un repositorio in-memory temporal;
4. crea el ViewModel y su estado;
5. construye la nueva View en `lib/ui/features`;
6. registra dependencias;
7. cambia la ruta hacia la nueva View;
8. elimina solo los archivos heredados que quedaron sin consumidores.

No crear wrappers nuevos alrededor de una pantalla monolítica manteniendo toda su lógica interna; eso cambia la carpeta, no la arquitectura.

### Vista completa frente a archivo individual

- Preferir migrar una View y sus widgets directos como una vertical pequeña.
- Un archivo individual solo se refactoriza aisladamente cuando su API permite mantener separación de responsabilidades.
- Si un widget heredado mezcla datos, provider, navegación y responsive, crear un widget nuevo en la feature y dejar el antiguo para consumidores aún no migrados.
- No convertir automáticamente todos los widgets de `presentation/widgets` en widgets de `ui/core`; primero demostrar que son realmente compartidos por al menos dos features migradas.
- Actualizar [MIGRATION_TRACKER.md](MIGRATION_TRACKER.md) al cambiar la ruta o retirar compatibilidad.

## Diseño y tema como dependencia de UI

- Las Views consumen `ThemeData`; no importan paletas privadas para reconstruir el mismo diseño en cada feature.
- Los componentes de feature pueden usar tokens lógicos de `ui/core/theme` para spacing, radius, tamaños mínimos y anchos máximos.
- Colores de negocio compartidos se modelan con `ThemeExtension` y variantes light/dark.
- `ThemeController` controla `ThemeMode`; no debe contener reglas de layout.
- La limpieza de temas ScreenUtil es transversal y se realiza al final, después de migrar todos sus consumidores.

## Reglas específicas por feature

### Autenticación

- credenciales y envío viven en el ViewModel/repositorio;
- el router observa el estado de sesión y aplica redirects;
- la View no navega a Home simulando autenticación exitosa.

### Requisas

- filtros, búsqueda, paginación, caché y offline no viven en la View;
- crear y finalizar son comandos protegidos contra doble ejecución;
- una requisa finalizada no se vuelve editable desde UI ni repositorio.

### Adquisición

- toda conexión necesita `requisitionId` y `acquisitionSessionId`;
- el ViewModel coordina capacidades y comandos, no bytes de video;
- Services nativos encapsulan USB/ADB/UVC;
- salir de la ruta debe producir cleanup explícito e idempotente.

## Criterio de revisión de código

- La View puede entenderse sin conocer red, DB o protocolo nativo.
- El ViewModel puede ejecutarse sin montar widgets.
- El Repository puede cambiar API por cache sin afectar la View.
- No existe `BuildContext` fuera de UI/navigation.
- No existen DTO de API en widgets.
- Los mocks son reemplazables y están detrás de contratos.
- La feature usa las reglas adaptive y declarative routing del proyecto.

Por instrucción del propietario, el agente no ejecuta tests, analyze ni compilación. La entrega debe quedar marcada como pendiente de validación por el propietario.
