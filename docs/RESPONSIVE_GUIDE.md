# Guía de UI adaptive y responsive

Esta guía es obligatoria junto con [ARCHITECTURE_GUIDE.md](ARCHITECTURE_GUIDE.md) y [ROUTING_GUIDE.md](ROUTING_GUIDE.md). El prompt ejecutable por fases está en [RESTRUCTURING_PROMPT.md](RESTRUCTURING_PROMPT.md).

> Límite de ejecución: las matrices y pruebas descritas aquí representan criterios que validará el propietario. Los agentes no deben crear ni ejecutar tests, `flutter analyze` o compilaciones salvo solicitud explícita.

Esta guía reemplaza la estrategia anterior basada en `OrientationBuilder`, “móvil/tablet” y escalado global con `flutter_screenutil`. La implementación nueva toma decisiones por **espacio disponible en la ventana o en el padre**, en píxeles lógicos.

El avance por vista se registra en [MIGRATION_TRACKER.md](MIGRATION_TRACKER.md). No confundir una vista ya adaptada con una migración global terminada: durante la transición todavía existe infraestructura legacy para pantallas no migradas.

## Principios obligatorios

1. Usar `MediaQuery.sizeOf(context)` cuando una pantalla necesite conocer el tamaño de la ventana completa.
2. Usar `LayoutBuilder` cuando un componente deba responder al espacio que le asigna su padre.
3. Decidir estructura por `constraints.maxWidth` y, solo cuando sea relevante, `constraints.maxHeight`.
4. No detectar hardware con `isPhone`, `isTablet` o diagonal física.
5. No cambiar el árbol principal solo con `OrientationBuilder`, `orientationOf` o `width > height`.
6. No bloquear orientación. Soportar vertical, horizontal, split-screen, foldables y ventanas redimensionables.
7. Usar `Expanded`/`Flexible` para distribuir espacio y `ConstrainedBox` para impedir estiramiento excesivo.
8. Usar `ListView.builder`, `GridView.builder` o slivers para colecciones dinámicas.
9. Mantener Views sin lógica de negocio. La View puede contener únicamente decisiones de layout, animación y routing simple; el ViewModel conserva el estado.
10. Respetar text scaling del sistema. No reducir fuentes en tablet para “hacer que entren”.

## Qué se retira gradualmente

No usar en código nuevo:

```text
DeviceInfo.isMobile / isTablet / isDesktop
DeviceInfo.isLandscape
OrientationBuilder para escoger toda la pantalla
.sw / .sh
.w / .h para spacing o tamaño de control
.sp para compensar manualmente el dispositivo
Responsive.widthPercent / heightPercent para tipografía
```

`flutter_screenutil`, `DeviceInfo` y `presentation/utils/responsive.dart` permanecen temporalmente solo para no romper widgets heredados. Se eliminan después de migrar sus consumidores y pruebas.

También permanecen temporalmente `ScreenUtilInit`/`OrientationBuilder` en `app.dart` y varios archivos de tema/tokens antiguos. Una View nueva no debe utilizarlos como justificación para importar responsive legacy.

## Frontera obligatoria entre código nuevo y legado

Los helpers responsive actuales son exclusivamente compatibilidad heredada. No deben importarse desde ninguna View o widget nuevo ni desde un archivo que ya haya sido migrado.

La infraestructura nueva se crea en:

```text
lib/ui/core/adaptive/
├── window_size_class.dart
├── adaptive_layout.dart
└── constrained_content.dart
```

Los tokens lógicos nuevos viven en `lib/ui/core/theme/` y no dependen de `BuildContext`, `MediaQuery` o ScreenUtil. Durante la transición pueden coexistir ambos sistemas, pero nunca mezclarse dentro de una feature migrada.

Una migración no se considera terminada si la nueva View todavía importa directa o indirectamente `device_type.dart`, `responsive_extension.dart`, `presentation/utils/responsive.dart` o `flutter_screenutil`.

### Decisiones de ventana y decisiones locales

- La View puede usar `AdaptiveLayout` una vez para conocer la clase general de ventana.
- Cada toolbar, card compleja, formulario o panel que dependa de su espacio propio usa `LayoutBuilder` local.
- No propagar decenas de booleanos como `isTablet` o `isLandscape`. Pasar estado y comandos; la composición visual se resuelve cerca del widget afectado.
- Ancho y altura son señales independientes. Un viewport puede ser `medium` y tener altura compacta.
- Mantener las mismas acciones y semántica en todas las variantes; solo cambia su colocación.

## Clases de espacio

Los nombres describen la ventana, no el dispositivo:

| Clase de ancho | Rango | Uso típico |
|---|---:|---|
| compact | `< 600` | una columna, navegación compacta |
| medium | `600–839` | contenido más ancho, grid/cards, dos zonas selectivas |
| expanded | `840–1199` | list-detail o panel de soporte |
| large | `>= 1200` | dos paneles amplios con contenido limitado |

Clases de altura:

| Clase de altura | Rango | Consecuencia |
|---|---:|---|
| compact | `< 480` | evitar dos paneles verticales, reducir chrome, permitir scroll |
| regular | `>= 480` | layout normal |

Un teléfono horizontal puede tener ancho `medium` pero altura `compact`; en ese caso no se fuerza un layout de tablet. Por eso las decisiones complejas evalúan ancho y altura.

## Implementación base propuesta

Crear `lib/ui/core/adaptive/window_size_class.dart`:

```dart
import 'package:flutter/widgets.dart';

enum WindowWidthClass { compact, medium, expanded, large }
enum WindowHeightClass { compact, regular }

@immutable
class AppWindowSize {
  const AppWindowSize({
    required this.width,
    required this.height,
  });

  factory AppWindowSize.fromConstraints(BoxConstraints constraints) {
    return AppWindowSize(
      width: switch (constraints.maxWidth) {
        < 600 => WindowWidthClass.compact,
        < 840 => WindowWidthClass.medium,
        < 1200 => WindowWidthClass.expanded,
        _ => WindowWidthClass.large,
      },
      height: constraints.maxHeight < 480
          ? WindowHeightClass.compact
          : WindowHeightClass.regular,
    );
  }

  final WindowWidthClass width;
  final WindowHeightClass height;

  bool get isCompact => width == WindowWidthClass.compact;
  bool get canShowSupportingPane =>
      (width == WindowWidthClass.expanded ||
       width == WindowWidthClass.large) &&
      height == WindowHeightClass.regular;
}
```

Crear `lib/ui/core/adaptive/adaptive_layout.dart`:

```dart
import 'package:file_cast/ui/core/adaptive/window_size_class.dart';
import 'package:flutter/widgets.dart';

typedef AdaptiveBuilder = Widget Function(
  BuildContext context,
  AppWindowSize window,
);

class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    required this.builder,
    super.key,
  });

  final AdaptiveBuilder builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(
          context,
          AppWindowSize.fromConstraints(constraints),
        );
      },
    );
  }
}
```

Una pantalla usa una sola entrada adaptive:

```dart
class RequisitionDetailView extends StatelessWidget {
  const RequisitionDetailView({
    required this.viewModel,
    super.key,
  });

  final RequisitionDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return AdaptiveLayout(
          builder: (context, window) {
            if (window.canShowSupportingPane) {
              return RequisitionDetailTwoPane(
                state: viewModel.state,
                commands: viewModel.commands,
              );
            }
            return RequisitionDetailSinglePane(
              state: viewModel.state,
              commands: viewModel.commands,
            );
          },
        );
      },
    );
  }
}
```

## Tokens: valores lógicos, no porcentajes

`AppDimensions` debe convertirse en constantes sin `BuildContext` ni ScreenUtil:

```dart
abstract final class AppSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const pill = 999.0;
}

abstract final class AppSize {
  static const minTouchTarget = 48.0;
  static const iconS = 16.0;
  static const iconM = 20.0;
  static const iconL = 24.0;
  static const formMaxWidth = 640.0;
  static const contentMaxWidth = 1200.0;
  static const supportingPaneWidth = 360.0;
}
```

La densidad de un layout puede elegir spacing `m` o `l`, pero no multiplicar todos los controles por el ancho. Un botón conserva target mínimo de 48 dp en cualquier ventana.

## Tipografía

La tipografía vive en `ThemeData.textTheme`. Los componentes eligen un rol semántico:

```dart
Text(
  state.title,
  style: Theme.of(context).textTheme.titleLarge,
)
```

No usar `FontTokens.body(context)` que cambia por supuesto tipo de equipo. Material/Flutter trabaja en píxeles lógicos y `MediaQuery.textScalerOf(context)` aplica la preferencia del usuario.

### Migración del tema

La migración del tema ocurre en dos tiempos:

1. **Durante la migración por vista:** consumir `Theme.of(context).colorScheme`, `cardColor`, `scaffoldBackgroundColor`, `textTheme` e `inputDecorationTheme`. No copiar colores ni tamaños legacy dentro de la View.
2. **En la limpieza global:** reemplazar `AppTextStyles`, `AppDimensions`, `AppTokens`, `FontTokens` y tokens de componentes que dependan de ScreenUtil/BuildContext por tokens lógicos en `lib/ui/core/theme/`.

Los estados semánticos que no pertenecen al `ColorScheme` estándar —por ejemplo `inProgress`, `finalized`, `offline`, `evidencePending` o el gradiente de acción— deben centralizarse en una `ThemeExtension`, con variantes light/dark y `copyWith`/`lerp`. Una feature no crea su propia paleta duplicada.

El estado final de `app.dart` será un `MaterialApp.router` directo:

```dart
return MaterialApp.router(
  theme: light,
  darkTheme: dark,
  themeMode: themeController.darkMode ? ThemeMode.dark : ThemeMode.light,
  routerConfig: appRouter,
);
```

No retirar `ScreenUtilInit` antes de que la búsqueda de consumidores legacy dé cero.

Reglas:

- no fijar altura de contenedores que llevan texto variable;
- usar padding y constraints mínimos;
- evitar `FittedBox` para hacer ilegible texto que no cabe;
- verificar escalas 1.0, 1.3, 1.6 y 2.0;
- truncar solo datos secundarios; títulos/errores críticos deben envolver o expandirse.

## Ancho de contenido

En ventanas grandes, centrar y limitar formularios/listas:

```dart
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: AppSize.formMaxWidth),
    child: RequisitionForm(state: state),
  ),
)
```

Para una pantalla completa:

```dart
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
    child: content,
  ),
)
```

No usar `0.85.sw` para el ancho de un botón dentro de un formulario; usar `SizedBox(width: double.infinity)` dentro del `ConstrainedBox`.

## Colecciones

### Cards que cambian de columna

```dart
GridView.builder(
  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 460,
    mainAxisSpacing: AppSpace.m,
    crossAxisSpacing: AppSpace.m,
    childAspectRatio: 1.7,
  ),
  itemCount: items.length,
  itemBuilder: (context, index) => RequisitionCard(item: items[index]),
)
```

Si la card tiene altura variable por text scaling, evitar `mainAxisExtent` rígido o diseñar un extent que contemple la escala máxima validada.

### Lista/tabla

- `compact`: cards verticales con campos esenciales.
- `medium`: una o dos columnas de cards según constraint local.
- `expanded/large`: lista densa o tabla con fecha, CUD/caso, estado, evidencia y acción.
- La semántica y acciones deben ser idénticas entre variantes.

No construir los hijos con `.map(...).toList()` dentro de un `Column` si la cantidad es dinámica; usar builders/slivers.

## Comportamiento por pantalla

### Started

- `compact`: contenido vertical; marca arriba, mensaje y CTA abajo; scroll si la altura es compacta.
- `medium+` con altura regular: composición horizontal opcional.
- La ilustración/folders usa el ancho de sus constraints (`SizedBox.expand`/`Positioned.fill`), no `1.sw`.

No crear métodos `_buildPortrait`/`_buildLandscape`; crear variantes `_buildCompact` y `_buildWide` según espacio.

### Login

- `compact`: formulario de ancho completo con padding y scroll.
- `medium+`: formulario centrado `maxWidth: 480–640`; la decoración puede ocupar un supporting pane.
- `height < 480`: ocultar decoración no esencial y priorizar teclado/formulario.
- CTA `width: double.infinity`, nunca porcentaje de pantalla.

### Listado de requisas

- header flexible; filtros pasan a bottom sheet en `compact` y panel inline en `medium+`.
- búsqueda y “Crear requisa” no deben competir en una fila estrecha.
- cards en compact/medium; tabla en expanded.
- mostrar sincronización/offline en un status discreto pero accesible.

### Crear requisa

- `compact` o altura compacta: ruta/página full-screen con footer que respete teclado y safe area.
- `medium+`: diálogo `maxWidth: 680`, `maxHeight` limitado y cuerpo scrollable.
- el footer no debe superponerse al último campo; usar layout con `Expanded` y zona inferior separada.

### Detalle, mirror y evidencias

- `compact`: mirror/contenido principal; barra foto/grabación persistente; evidencias en tab o bottom sheet.
- `medium`: usar tabs o supporting pane solo si la altura es suficiente.
- `expanded/large` y altura regular: dos paneles como el mockup, con mirror `Expanded` y panel de evidencia de 320–400 dp.
- el área táctil del mirror se calcula con `LayoutBuilder` y aspect fit. La barra de captura queda fuera del `Listener` o su zona se resta explícitamente.
- paneles de logs solo en debug y deben adaptarse a constraints, no tener 280x200 fijo en ventanas pequeñas.

Ejemplo de dos paneles:

```dart
Row(
  children: [
    Expanded(
      flex: 3,
      child: AcquisitionPane(state: state),
    ),
    const VerticalDivider(width: 1),
    SizedBox(
      width: AppSize.supportingPaneWidth,
      child: EvidencePane(state: state),
    ),
  ],
)
```

En `large`, el supporting pane puede crecer con `Flexible`, limitado por `ConstrainedBox(maxWidth: 440)`.

## Inputs y accesibilidad

- target táctil mínimo 48x48 dp;
- soportar mouse, trackpad, teclado y stylus en tablets;
- orden de foco predecible y `Shortcuts` para capturar/iniciar grabación solo con confirmación adecuada;
- tooltips para icon buttons;
- semántica que anuncie estado de conexión/grabación/progreso;
- no depender solo del color para “conectado”, “error” o “finalizada”;
- contraste validado en dark/light;
- respetar `SafeArea`, teclado e insets del sistema;
- no bloquear orientación.

## Migración del código actual

### Paso 1 — infraestructura

- agregar `window_size_class.dart` y `adaptive_layout.dart`;
- convertir spacing/radius/icon/touch target a constantes lógicas;
- definir TextTheme definitivo;
- añadir helpers de `ConstrainedContent` y `AdaptiveBuilder`.

### Paso 2 — pantallas pequeñas y aisladas

Migrar, en orden:

1. `started.dart`;
2. `login.dart`;
3. modal de crear requisa;
4. listado/home;
5. USB connect;
6. mirror/detalle.

En cada migración:

- envolver el área relevante en `LayoutBuilder`;
- reemplazar hardware/orientation branches por width/height class;
- quitar `.w/.h/.sp/.sw/.sh` del archivo;
- limitar ancho en pantallas grandes;
- probar todos los viewports antes de pasar al siguiente.

### Paso 3 — retiro

Cuando no tengan consumidores:

- borrar `lib/core/responsive/device_type.dart`;
- borrar `lib/core/responsive/responsive_extension.dart`;
- borrar `lib/presentation/utils/responsive.dart`;
- retirar `flutter_screenutil` del `pubspec.yaml`;
- reemplazar `ScreenUtilInit`/`OrientationBuilder` de `app.dart` por `MaterialApp.router` directo.
- consolidar `theme_light.dart`/`theme_dark.dart` sobre tokens lógicos y `ThemeExtension` semánticas;
- retirar `AppDimensions`, `AppTextStyles`, `AppTokens`, `FontTokens` y tokens antiguos únicamente si no tienen consumidores;
- eliminar widgets/páginas legacy solo después de verificar imports, exports, rutas y referencias.

Este paso se ejecuta con el prompt final de [RESTRUCTURING_PROMPT.md](RESTRUCTURING_PROMPT.md) y requiere cumplir el gate de [MIGRATION_TRACKER.md](MIGRATION_TRACKER.md).

## Matriz de pruebas de viewport

Usar dimensiones lógicas, no nombres de modelo como condición de código:

| Viewport | Propósito |
|---:|---|
| 320 x 568 | teléfono pequeño vertical |
| 360 x 800 | teléfono común vertical |
| 412 x 915 | teléfono grande vertical |
| 568 x 320 | altura compacta horizontal |
| 800 x 360 | ancho medium/altura compacta |
| 600 x 960 | límite medium |
| 800 x 1280 | tablet vertical |
| 1024 x 768 | expanded horizontal |
| 1280 x 800 | large/tablet grande |
| 673 x 841 | ventana/foldable no estándar |

Cruzar cada uno con:

- text scale 1.0, 1.3, 1.6 y 2.0;
- español con strings largos;
- teclado abierto/cerrado;
- dark/light;
- datos vacíos, máximos y error;
- mirror vertical/horizontal;
- split-screen cuando el sistema lo soporte.

## Tests automatizados

Crear un helper que bombee una View con `MediaQuery` y tamaño fijo. Para cada feature:

- widget tests en los bordes 599/600, 839/840 y 1199/1200;
- golden compact, medium y expanded;
- assertions de ausencia de overflow/excepciones;
- pruebas con text scaling 2.0;
- prueba de que acciones y semántica existen en todas las variantes.

Ejemplo conceptual:

```dart
await tester.binding.setSurfaceSize(const Size(840, 900));
await tester.pumpWidget(
  buildTestApp(RequisitionDetailView(viewModel: fakeViewModel)),
);
await tester.pumpAndSettle();

expect(find.byType(RequisitionDetailTwoPane), findsOneWidget);
expect(tester.takeException(), isNull);
```

## Checklist de revisión

- [ ] La decisión usa constraint local o tamaño de ventana, no tipo de hardware.
- [ ] No existe branch principal por orientación.
- [ ] La UI funciona con altura compacta.
- [ ] No hay `.sw/.sh` ni porcentajes de altura para texto.
- [ ] Formularios y paneles tienen `maxWidth`.
- [ ] Listas/grids dinámicos usan builder.
- [ ] `Expanded`/`Flexible` distribuyen filas y columnas.
- [ ] Targets táctiles son al menos 48 dp.
- [ ] Text scale 2.0 no corta acciones críticas.
- [ ] Se probaron ancho 599/600 y 839/840.
- [ ] La View solo contiene lógica de layout/presentación.
- [ ] No se bloqueó orientación.
- [ ] Teclado, safe area, mouse y foco fueron verificados.

## Fuentes

- [Flutter: general approach to adaptive apps](https://docs.flutter.dev/ui/adaptive-responsive/general)
- [Flutter: guide to app architecture](https://docs.flutter.dev/app-architecture/guide)
- [Android: window size classes](https://developer.android.com/develop/adaptive-apps/guides/use-window-size-classes)
- [Android: large-screen quality](https://developer.android.com/guide/topics/large-screens)
