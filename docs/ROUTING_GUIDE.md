# Guía de navegación declarativa

File Cast usa `go_router` y `MaterialApp.router`. Esta guía reemplaza la navegación fragmentada actual y define cómo deben registrarse nuevas vistas.

La ruta de una vista solo cambia cuando su migración está completa. Registrar el avance en [MIGRATION_TRACKER.md](MIGRATION_TRACKER.md); no retirar `presentation/routes` mientras conserve consumidores.

## Estado actual

La aplicación ya usa `MaterialApp.router`, pero todavía existen estos problemas:

- rutas planas sin jerarquía de requisa;
- `Navigator.push` y `MaterialPageRoute` dentro del laboratorio USB;
- parámetros del mirror enviados como `Map<String, dynamic>`;
- una ruta puede lanzar una excepción si falta un argumento;
- Home representa el listado, pero su URL es `/` y no expresa el recurso;
- no existe redirect central de autenticación;
- la adquisición no incluye requisition/session ID en la ruta.

La migración debe ocurrir por feature. No se cambia el prototipo nativo hasta migrar adquisición.

## Ubicación canónica

```text
lib/ui/core/navigation/
├── app_route.dart             # nombres y paths
├── app_router.dart            # árbol GoRouter
├── app_route_error_view.dart
├── app_redirect.dart          # auth/authorization
└── route_args/                # argumentos tipados efímeros
```

No crear rutas nuevas en `lib/presentation/routes/`. Esa carpeta queda como compatibilidad hasta completar la migración.

## Árbol objetivo

```text
/started
/login
/requisitions
/requisitions/new
/requisitions/:requisitionId
/requisitions/:requisitionId/acquisition/connect
/requisitions/:requisitionId/acquisition/:sessionId/mirror
/requisitions/:requisitionId/acquisition/:sessionId/transfer
/settings
/offline
```

`/` debe redirigir según sesión:

- sin sesión válida -> `/login` o `/started` según onboarding;
- con sesión válida -> `/requisitions`.

## Identidad y parámetros

- IDs de negocio obligatorios van en `pathParameters`.
- Filtros restaurables/compartibles pueden ir en `queryParameters`.
- `extra` se reserva para handles efímeros tipados, como un descriptor nativo que no puede serializarse.
- Nunca enviar `Map<String, dynamic>` como contrato entre vistas.
- Una ruta recargada debe poder reconstruir el recurso mediante sus IDs o mostrar un fallback explícito.
- Un handle de textura no sustituye `sessionId`; si el proceso lo pierde, la View muestra “sesión no disponible” en lugar de lanzar una excepción.

Ejemplo conceptual:

```dart
abstract final class AppRouteName {
  static const requisitions = 'requisitions';
  static const requisitionDetail = 'requisition-detail';
  static const acquisitionConnect = 'acquisition-connect';
  static const acquisitionMirror = 'acquisition-mirror';
}

@immutable
class MirrorRouteArgs {
  const MirrorRouteArgs({
    required this.textureId,
    required this.controlLocalId,
    required this.videoSize,
  });

  final int textureId;
  final int controlLocalId;
  final Size videoSize;
}
```

## Navegación desde UI

Permitido dentro de Views:

```dart
context.goNamed(AppRouteName.requisitions);
context.pushNamed(
  AppRouteName.requisitionDetail,
  pathParameters: {'requisitionId': requisition.id},
);
context.pop();
```

No permitido en código nuevo o migrado:

```dart
Navigator.of(context).push(MaterialPageRoute(...));
Navigator.pushNamed(context, ...);
viewModel.openScreen(context);
```

Los ViewModels emiten el resultado de una acción; la View decide la transición. Los ViewModels nunca reciben `BuildContext` o `GoRouter`.

## Autenticación y redirects

El router debe observar una fuente de sesión `Listenable` y reevaluar redirects:

```text
unknown/loading -> pantalla de arranque
unauthenticated -> login
authenticated en login/started -> requisitions
authenticated -> ruta solicitada
```

El redirect no debe consultar HTTP directamente. Consume el estado ya resuelto por el controlador/repositorio de sesión y evita loops comparando la ubicación actual.

La autorización de una requisa se valida también en repositorio/backend; ocultar una ruta en UI no es seguridad suficiente.

## Shell adaptativo

Usar `StatefulShellRoute.indexedStack` solamente cuando el producto tenga destinos persistentes reales, por ejemplo Requisas, Sincronización y Ajustes.

El shell se adapta por espacio:

- compact: `NavigationBar` o navegación jerárquica;
- medium/expanded: `NavigationRail` si mejora el flujo;
- no crear un bottom bar con una sola sección;
- las rutas de login, creación modal/full-screen y mirror pueden vivir fuera del shell.

La elección visual del shell usa `LayoutBuilder`; el árbol de rutas no depende de “móvil/tablet”.

## Ciclo de vida de adquisición

- La ruta de conexión se crea desde el detalle de una requisa.
- Al comenzar adquisición, se genera un `sessionId` persistible.
- Mirror y transferencia son hijos conceptuales de requisa/sesión.
- Abandonar una ruta no debe dejar USB, decoder o grabación activos; el scope de adquisición ejecuta cleanup idempotente.
- Back debe pedir confirmación cuando exista una grabación o transferencia activa.
- La navegación no contiene la lógica de cleanup; invoca el comando correspondiente y reacciona a su resultado.

## Error y recuperación

Configurar `errorBuilder` o `errorPageBuilder` para rutas desconocidas y parámetros inválidos. La pantalla de error debe permitir:

- volver a requisiciones;
- reintentar cargar el recurso;
- informar ID inválido o sesión expirada sin exponer stack traces.

No usar `throw Exception` dentro de un route builder como experiencia de usuario.

## Deep links

La estructura de paths queda preparada para deep linking, pero no configurar Android App Links ni iOS Universal Links hasta definir:

- dominio HTTPS oficial;
- package IDs/flavors definitivos;
- fingerprints de firma Android;
- Team ID y Associated Domains de iOS;
- política de autenticación al abrir una requisa enlazada.

Cuando esos datos existan, seguir la skill `flutter-setup-declarative-routing` y documentar la configuración por flavor.

## Orden de migración

1. Crear `app_route.dart`, error view y router canónico.
2. Migrar Started y Login.
3. Agregar redirect basado en sesión real.
4. Migrar `/requisitions`, creación y detalle.
5. Introducir shell solo si se confirman destinos persistentes.
6. Migrar Settings/Offline.
7. Migrar USB/connect/mirror reemplazando `Navigator.push` y mapas dinámicos.
8. Eliminar `lib/presentation/routes/` cuando no tenga consumidores.

El paso 8 pertenece a la limpieza global final de [RESTRUCTURING_PROMPT.md](RESTRUCTURING_PROMPT.md). Antes de ejecutarlo se deben buscar imports, exports, nombres de ruta y navegaciones heredadas; una ruta nueva no demuestra por sí sola que el adaptador antiguo ya no se usa.

## Checklist de revisión

- [ ] `MaterialApp.router` recibe una única configuración central.
- [ ] La ruta expresa el recurso y contiene sus IDs obligatorios.
- [ ] No hay `Navigator.push`/`MaterialPageRoute` en la feature migrada.
- [ ] No hay `Map<String, dynamic>` como contrato de navegación.
- [ ] La ViewModel no conoce Flutter navigation.
- [ ] Auth se resuelve con redirect central sin loops.
- [ ] Parámetros inválidos muestran fallback.
- [ ] El ciclo de vida de la ruta libera recursos de adquisición.
- [ ] Las rutas nuevas pueden evolucionar a deep links.

Por instrucción del propietario, la implementación no debe ejecutar tests, analyze ni compilación; estas validaciones quedan a su cargo.
