# Reglas de trabajo para File Cast

Estas reglas aplican a todo el repositorio. Antes de modificar código, conservar los cambios existentes del propietario y leer el contexto aplicable.

## Contexto obligatorio

- Leer `docs/PROJECT_STATUS_AND_FEASIBILITY.md` y `docs/IMPLEMENTATION_PLAN.md` para cambios de producto.
- Leer `docs/HARDWARE_REQUIREMENTS.md` y `docs/ADB_HANDSHAKE.md` para adquisición, USB, ADB, scrcpy, iOS o hardware.
- Leer `docs/SINGLE_VIEW_REFACTOR_PROMPT.md` cuando el alcance sea una View o feature visual.

Las skills contienen las prácticas generales; este archivo contiene las decisiones específicas y obligatorias de File Cast.

## Skills obligatorias

- Estructura, estado, dominio, datos o features: `.agents/skills/flutter-apply-architecture-best-practices/SKILL.md`.
- Cualquier View, widget, modal o adaptación visual: `.agents/skills/flutter-build-responsive-layout/SKILL.md`.
- Rutas, guards, shells, parámetros o deep links: `.agents/skills/flutter-setup-declarative-routing/SKILL.md`.

Leer completamente cada skill aplicable antes de actuar. Si una tarea toca las tres áreas, usar las tres.

## Validación reservada al propietario

- No ejecutar `flutter test`, `flutter analyze`, `flutter run`, `flutter build`, compilaciones nativas ni generadores.
- No agregar tests salvo petición explícita.
- Se permite inspeccionar, buscar referencias, revisar diffs y ejecutar `dart format`.
- La entrega debe indicar que el código no fue compilado ni validado automáticamente.

## Arquitectura obligatoria

```text
View -> ViewModel -> UseCase opcional -> Repository -> Service
```

- `lib/ui/features/` contiene Views, ViewModels y widgets propios de cada feature.
- `lib/ui/core/` contiene infraestructura visual realmente compartida: adaptive, navigation, theme y widgets.
- `lib/domain/` no depende de Flutter, UI, plugins ni implementaciones de datos.
- `lib/data/` implementa repositorios y adapta servicios/DTO.
- Una View renderiza estado, maneja layout/foco/animación y emite intenciones. No ejecuta HTTP, almacenamiento, acceso nativo, IO, hashing, mocks ni reglas de negocio.
- Un ViewModel no recibe `BuildContext`, `GoRouter` ni widgets. Recibe dependencias por constructor y expone estado inmutable.
- Los repositorios son la fuente de verdad. Los servicios envuelven HTTP, almacenamiento, plugins o canales nativos.
- Crear Use Cases únicamente para reglas reutilizables o coordinación de varios repositorios.
- Registrar dependencias con `provider` en `lib/core/di/dependency_injection.dart`; evitar service locators ocultos.
- Usar Freezed en nuevos modelos de dominio, DTO y snapshots de estado. JSON solo para DTO que crucen una frontera.
- No editar manualmente `*.freezed.dart` ni `*.g.dart`; el propietario ejecuta `build_runner`.

Estructura de una feature:

```text
lib/ui/features/<feature>/
├── view_models/
├── views/
└── widgets/
```

## Views y widgets

- La View contenedora debe ser pequeña; dividir secciones con responsabilidad visual clara.
- Pasar datos y callbacks a widgets; no consultar providers arbitrariamente desde niveles profundos.
- Representar explícitamente `loading`, `empty`, `content`, `offline` y `error` cuando apliquen.
- Para listas dinámicas usar `ListView.builder`, slivers u otros builders; no `.map(...).toList()` dentro de `Column`.
- Mantener las mismas acciones y semántica en todos los tamaños.
- Preservar el estilo de los mockups y del tema. Adaptar layout no autoriza rediseñar la identidad visual.
- Promover un widget a `ui/core/widgets` solo cuando al menos dos features demuestren un contrato común.

## Responsive y adaptive

La infraestructura canónica está en `lib/ui/core/adaptive/`. Los valores visuales lógicos viven en `lib/ui/core/theme/layout_tokens.dart`.

- Tomar decisiones locales con `LayoutBuilder` y `constraints.maxWidth/maxHeight`.
- Usar `MediaQuery.sizeOf(context)` solo cuando se necesite la ventana completa.
- Clases: compact `<600`, medium `600..839`, expanded `840..1199`, large `>=1200`; altura compacta `<480`.
- Usar `Expanded`/`Flexible` para repartir espacio y `ConstrainedBox` para mantener anchos legibles.
- Usar píxeles lógicos constantes para espacios, radios, iconos y tipografía. Flutter aplica el escalado de texto del usuario.
- Respetar `SafeArea`, teclado e insets, text scaling, mouse, teclado físico y targets táctiles mínimos de 48 dp.
- No bloquear orientación ni escoger el árbol principal por portrait/landscape, marca o tipo físico de equipo.
- No introducir `flutter_screenutil`, `.sw/.sh/.sp/.w/.h/.r`, `DeviceInfo` responsive, porcentajes de pantalla, `OrientationBuilder` ni helpers paralelos.

`layout_tokens.dart` no decide el responsive: ofrece constantes semánticas. Los constraints deciden composición y distribución.

## Tema

- `theme_light.dart` y `theme_dark.dart` son las fuentes de `ThemeData`; la UI consume `Theme.of(context)`.
- Los colores semánticos nuevos pertenecen a `ColorScheme` o `ThemeExtension`, no a paletas privadas de una feature.
- `AppTextTheme` y `layout_tokens.dart` usan valores lógicos estables, sin escalado por tamaño de pantalla.
- Mantener jerarquía, colores, iconografía y radios existentes salvo solicitud explícita de rediseño.

## Navegación

- Usar exclusivamente `MaterialApp.router` y el router central de `lib/ui/core/navigation/`.
- Navegar con `go_router`; no usar `Navigator.push`, `MaterialPageRoute`, rutas anónimas ni mapas dinámicos de argumentos.
- Los IDs de negocio restaurables van en path parameters. Filtros compartibles/restaurables van en query parameters.
- `extra` solo transporta objetos tipados y efímeros; nunca es la única fuente de un ID de negocio.
- Los guards de autenticación/autorización viven en redirects centrales.
- Toda ruta debe ofrecer fallback visible ante argumentos efímeros ausentes o inválidos.
- Las rutas de adquisición incluyen `requisitionId` y `sessionId`.
- Un ViewModel nunca navega ni conoce `BuildContext`.
- No crear `StatefulShellRoute` si no existe navegación persistente real.

## Adquisición y seguridad

- Preservar el protocolo USB/ADB/scrcpy nativo al cambiar UI; una reescritura de protocolo requiere alcance explícito.
- Toda adquisición debe quedar ligada a requisa y sesión.
- Mantener capacidad offline conceptual y preparar evidencias con metadatos, hash y cadena de custodia.
- No prometer paridad iOS con ADB/scrcpy ni acceso a datos privados de otras apps.
- No ampliar a App Links/Universal Links sin dominio, hosts y credenciales aprobados.
- Antes de retirar archivos o dependencias, buscar imports, exports, rutas y consumidores.

## Entrega

Informar:

1. feature y pantallas afectadas;
2. estructura creada o retirada;
3. lógica movida fuera de Views;
4. comportamiento responsive relevante;
5. rutas y parámetros modificados;
6. deuda real que permanezca;
7. que no se ejecutaron tests, analyze, build, run ni generadores.
