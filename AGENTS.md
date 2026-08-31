# Reglas de trabajo para File Cast

Este archivo aplica a todo el repositorio. Todo agente debe leerlo antes de modificar código y conservar los cambios existentes del usuario.

## Contexto obligatorio

Antes de implementar o refactorizar Flutter, leer:

- `docs/PROJECT_STATUS_AND_FEASIBILITY.md`
- `docs/IMPLEMENTATION_PLAN.md`
- `docs/ARCHITECTURE_GUIDE.md`
- `docs/RESPONSIVE_GUIDE.md`
- `docs/ROUTING_GUIDE.md`
- `docs/SINGLE_VIEW_REFACTOR_PROMPT.md` cuando el alcance sea una sola View o archivo.
- `docs/HARDWARE_REQUIREMENTS.md` cuando el cambio involucre adquisición o conexiones.

Las decisiones de estos documentos son obligatorias. Si el código heredado las contradice, el código heredado es la parte que debe migrarse progresivamente.

## Skills obligatorias

Para cambios de estructura, estado, datos o nuevas features, usar y leer completamente:

- `.agents/skills/flutter-apply-architecture-best-practices/SKILL.md`

Para cualquier vista, widget, modal, navegación adaptativa o cambio visual, usar y leer completamente:

- `.agents/skills/flutter-build-responsive-layout/SKILL.md`

Para rutas, guards, shell, navegación, parámetros o deep links, usar y leer completamente:

- `.agents/skills/flutter-setup-declarative-routing/SKILL.md`

Si una tarea toca más de una de estas áreas, se usan todas las skills aplicables.

## Límite de validación solicitado por el propietario

- No ejecutar `flutter test`, `flutter analyze`, `flutter run`, `flutter build`, compilaciones nativas ni generadores de código.
- No agregar tests como parte de una refactorización salvo petición explícita.
- El propietario realizará la compilación y validación.
- Se permite inspeccionar archivos, buscar referencias y revisar diffs.
- Al entregar, declarar claramente que los cambios no fueron compilados ni validados automáticamente.

## Arquitectura objetivo

Aplicar MVVM y separación estricta UI / dominio / datos:

```text
View -> ViewModel -> UseCase opcional -> Repository -> Service
```

- Las Views renderizan estado y emiten intenciones. Solo contienen layout, animación, foco y navegación simple.
- No hacer HTTP, almacenamiento, acceso nativo, hashing, filtrado de negocio ni construcción de datos mock dentro de una View.
- Los ViewModels extienden `ChangeNotifier` o exponen `Listenable`, reciben dependencias por constructor y publican snapshots inmutables.
- Los repositorios son la única fuente de verdad y ocultan API, caché, base local y sincronización.
- Los servicios son stateless y envuelven HTTP, almacenamiento, plugins o canales nativos.
- Crear Use Cases solo cuando una operación combine reglas, varios repositorios o deba reutilizarse.
- Registrar dependencias con `provider` en el composition root; no obtener dependencias globales ocultas dentro de dominio o datos.
- No pasar `BuildContext` a ViewModels, repositorios, Use Cases o servicios.
- Usar Freezed para modelos de dominio, DTO y snapshots de estado nuevos. Declarar sus `part` y factories en el archivo fuente.
- Agregar `fromJson`/`toJson` solo en DTO que crucen una frontera de datos; los modelos de dominio y estados de UI no necesitan JSON por defecto.
- No escribir ni modificar manualmente archivos `*.freezed.dart` o `*.g.dart`. El propietario ejecutará `build_runner`.

La estructura canónica para código nuevo es:

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
        └── <feature>/
            ├── view_models/
            ├── views/
            └── widgets/
```

`lib/presentation/` es legado. No crear nuevas features allí. Migrar una pantalla completa a `lib/ui/features/` y cambiar su ruta únicamente cuando la nueva versión esté lista; no realizar un rename masivo.

## Reglas para Views nuevas o migradas

- Una pantalla tiene una View contenedora pequeña, un ViewModel y widgets de feature reutilizables.
- Recibir estado/datos por parámetros; evitar que widgets de presentación consulten providers arbitrariamente en niveles profundos.
- Separar estados `loading`, `empty`, `content`, `offline` y `error` de forma explícita.
- No colocar listas dinámicas en `Column` usando `.map(...).toList()`; usar builders o slivers.
- No duplicar reglas de negocio entre variantes compact/medium/expanded.
- Mantener las acciones y semántica equivalentes en todas las variantes.
- Preservar el estilo visual definido por tema y mockups, pero no copiar la estructura responsive heredada.
- No migrar widgets genéricos sin uso en la feature actual.

## Responsive y adaptive obligatorios

Para código nuevo o migrado, usar exclusivamente la infraestructura canónica de `lib/ui/core/adaptive/` definida en `docs/RESPONSIVE_GUIDE.md`.

Prohibido en código nuevo o migrado:

- `flutter_screenutil`
- `.sw`, `.sh`, `.sp`, `.w`, `.h` o `.r`
- `DeviceInfo.isMobile`, `isTablet`, `isDesktop` o `isLandscape`
- `Responsive.widthPercent`, `heightPercent` o diagonal física
- `OrientationBuilder` o `MediaQuery.orientationOf` para escoger el árbol principal
- condicionar por marca, modelo o tipo físico de equipo
- bloquear orientación

Reglas:

- Usar `LayoutBuilder` y `constraints.maxWidth/maxHeight` para decisiones locales.
- Usar `MediaQuery.sizeOf(context)` solo cuando se necesite el tamaño completo de la ventana.
- Clases de ancho: compact `<600`, medium `600..839`, expanded `840..1199`, large `>=1200`.
- Altura compacta: `<480`.
- Usar `Expanded`/`Flexible` para repartir espacio y `ConstrainedBox` para limitarlo.
- Formularios y texto deben tener un ancho máximo legible en ventanas grandes.
- Respetar `SafeArea`, teclado, insets, escalado de texto, mouse, teclado y targets táctiles mínimos de 48 dp.
- No eliminar los helpers responsive heredados hasta que no tengan consumidores; tampoco importarlos desde archivos migrados.

## Navegación declarativa obligatoria

- Usar únicamente `MaterialApp.router` y la configuración central de `go_router`.
- La configuración canónica vive en `lib/ui/core/navigation/` según `docs/ROUTING_GUIDE.md`.
- Las rutas representan recursos: requisition ID y acquisition session ID van en path parameters.
- Usar query parameters solo para filtros o estado compartible/restaurable.
- No usar `Navigator.push`, `MaterialPageRoute` ni rutas anónimas en código nuevo o migrado.
- No pasar argumentos mediante `Map<String, dynamic>`.
- `extra` solo se permite para objetos tipados, efímeros y no restaurables; nunca debe ser la única fuente de un ID de negocio.
- Navegar desde Views con `go`, `push`, `goNamed`, `pushNamed` o `pop`. Los ViewModels no dependen de `BuildContext` ni `GoRouter`.
- Centralizar redirects de autenticación y autorización. Una View no decide manualmente el guard de otra ruta.
- Toda ruta debe tener estado de error/fallback; un argumento ausente no debe lanzar una excepción sin UI.
- Usar `StatefulShellRoute` solo si existe navegación persistente real. No introducir tabs ficticios.
- Las pantallas de adquisición deben incluir `requisitionId` y `sessionId` en su identidad de navegación.
- Migrar usos heredados de `Navigator` al refactorizar la feature correspondiente; no mezclar ambos estilos dentro de una feature migrada.

## Alcance y seguridad de la migración

- Trabajar por verticales pequeños: infraestructura -> Started/Login -> requisas -> detalle -> adquisición.
- Preservar el prototipo USB/ADB/scrcpy mientras se refactoriza UI; no cambiar protocolo nativo en una tarea visual.
- No borrar código responsive heredado globalmente hasta migrar todos sus consumidores.
- No modificar archivos generados (`*.freezed.dart`, `*.g.dart`) manualmente.
- No introducir backend ficticio dentro de Views. Si se necesita conservar un mock, colocarlo detrás de un repositorio in-memory reemplazable.
- No ampliar el alcance a deep links universales, Android App Links o iOS Universal Links sin dominio, hosts y credenciales aprobados.
- Mantener la compatibilidad conceptual con funcionamiento offline y sesiones ligadas a una requisa.

## Entrega de cada refactorización

El resumen final debe indicar:

1. feature y pantallas migradas;
2. estructura nueva creada;
3. lógica retirada de las Views;
4. imports responsive heredados eliminados de los archivos migrados;
5. rutas migradas a `go_router`;
6. código heredado que continúa pendiente;
7. que no se ejecutaron tests, analyze ni compilación por instrucción del propietario.
