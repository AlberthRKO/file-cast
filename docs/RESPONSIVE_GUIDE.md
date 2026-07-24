# Guía de Responsive y Arquitectura de Tokens

## Arquitectura actual

```
core/theme/
├── app_dimensions.dart      ← Primitivos puros (sin context)
├── tokens/
│   ├── font_tokens.dart     ← Decisiones de tipografía por dispositivo
│   └── component_tokens.dart ← Decisiones de componentes por dispositivo
├── app_tokens.dart          ← Fachada (compatibilidad hacia atrás)
├── app_text_styles.dart     ← TextTheme de Material
└── colors.dart              ← Constantes de color
```

### Relación entre capas

```
AppDimensions (primitivos: .w, .h, .sp, .r)
    ↓ usa como base
FontTokens / ComponentTokens (agregan lógica de DeviceInfo)
    ↓ delega
AppTokens (fachada para código legado)
```

---

## Regla fundamental

> **Ningún widget de `presentation/pages` debe decidir tamaños con `if/?` basados en orientación o dispositivo.**

| Tipo de decisión | Dónde vive | Ejemplo |
|---|---|---|
| Valor que escala proporcionalmente | Directo en widget con `.w`, `.h`, `.sp`, `.r` | `SizedBox(height: 8.h)` |
| Valor que cambia según tablet/móvil/orientación | `AppTokens`, `FontTokens` o `ComponentTokens` | `FontTokens.body(context)` |
| Estructura del layout (columnas, mostrar/ocultar) | `if/ternario` en el widget de página | `_buildPortrait` vs `_buildLandscape` |

---

## Cómo crear un widget nuevo

### 1. Si necesita primitivos puros (sin lógica de dispositivo)

Usa `AppDimensions` directamente. No necesita `BuildContext`.

```dart
SizedBox(height: AppDimensions.spaceM)
BorderRadius.circular(AppDimensions.radiusS)
```

### 2. Si necesita tamaños que varían por dispositivo

Crea un token en la capa correspondiente:

**Para fuentes** → `core/theme/tokens/font_tokens.dart`:
```dart
static double miToken(BuildContext context) {
  final device = DeviceInfo.of(context);
  return device.isTablet ? 14.sp : 12.sp;
}
```

**Para componentes** → `core/theme/tokens/component_tokens.dart`:
```dart
static double miAltura(BuildContext context) {
  final device = DeviceInfo.of(context);
  if (device.isTablet) {
    return device.isLandscape
        ? AppDimensions.buttonHeightM
        : AppDimensions.buttonHeightL;
  }
  return device.isLandscape
      ? AppDimensions.buttonHeightS
      : AppDimensions.buttonHeightM;
}
```

**Para espaciados** → Solo si el espaciado cambia por dispositivo. Si no, usa `AppDimensions` directo.

### 3. Agrega el export en `core/core.dart`

```dart
export 'theme/tokens/mi_nuevo_token.dart';
```

### 4. Usa en tu widget

```dart
Text(
  'Hola',
  style: TextStyle(fontSize: FontTokens.body(context)),
)

CustomButtonBoxStyle(
  sizeHeight: ComponentTokens.buttonHeight(context),
  fontSize: FontTokens.body(context),
)
```

---

## Cómo crear una página nueva

### Patrón obligatorio: `_buildPortrait` / `_buildLandscape`

```dart
class MiPagina extends StatelessWidget {
  const MiPagina({super.key});

  @override
  Widget build(BuildContext context) {
    final device = DeviceInfo.of(context);

    return Scaffold(
      body: device.isLandscape
          ? _buildLandscape(context, device)
          : _buildPortrait(context, device),
    );
  }

  Widget _buildPortrait(BuildContext context, DeviceInfo device) {
    return Column(
      children: [
        // header fijo arriba
        _buildHeader(context),
        // contenido expandible
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildLandscape(BuildContext context, DeviceInfo device) {
    return Row(
      children: [
        // header a la izquierda
        SizedBox(width: 0.4.sw, child: _buildHeader(context)),
        // contenido a la derecha
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) { ... }
  Widget _buildContent(BuildContext context) { ... }
}
```

### Reglas para la página

1. **Separación de estructura**: `_buildPortrait` usa `Column`, `_buildLandscape` usa `Row`
2. **Sin ternarios de tamaño**: No uses `isLandscape ? 30.h : 48.h` → Eso va en un token
3. **Sin `.w` para anchos absolutos**: `ConstrainedBox(maxWidth: 500.0)` no `500.w`
4. **LayoutBuilder para posiciones dinámicas**: Cuando necesites posiciones relativas al espacio real
5. **Tokens para todo lo demás**: `FontTokens`, `ComponentTokens`, `AppDimensions`

---

## Configuración de ScreenUtil

`app.dart` usa `OrientationBuilder` con designSize invertido:

```dart
OrientationBuilder(
  builder: (context, orientation) {
    final isPortrait = orientation == Orientation.portrait;
    return ScreenUtilInit(
      designSize: isPortrait ? const Size(375, 812) : const Size(812, 375),
      ...
    );
  },
)
```

**Por qué**: Sin la inversión, `.sp` y `.w` se inflan ~2.16x en landscape porque `scaleWidth = 812/375`. Con la inversión, `scaleWidth = 812/812 = 1.0` y todo se mantiene proporcional.

**El costo del rebuild**: Es mínimo. `appRouter` es singleton, el estado de navegación vive en el `RouterDelegate`, no se pierde al reconstruir `MaterialApp.router`.

---

## Referencia rápida de tokens

### AppDimensions (sin context)

| Token | Valor |
|---|---|
| `spaceXXS` | `2.w` |
| `spaceXS` | `4.w` |
| `spaceS` | `8.w` |
| `spaceM` | `16.w` |
| `spaceL` | `24.w` |
| `spaceXL` | `32.w` |
| `spaceXXL` | `48.w` |
| `radiusXS` | `4.r` |
| `radiusS` | `8.r` |
| `radiusM` | `12.r` |
| `radiusL` | `16.r` |
| `radiusXL` | `20.r` |
| `radiusFull` | `999.r` |
| `iconXS` | `12.r` |
| `iconS` | `16.r` |
| `iconM` | `20.r` |
| `iconL` | `24.r` |
| `iconXL` | `32.r` |
| `buttonHeightS` | `36.h` |
| `buttonHeightM` | `48.h` |
| `buttonHeightL` | `56.h` |
| `inputHeight` | `50.h` |

### FontTokens (con context)

| Token | Móvil | Tablet |
|---|---|---|
| `FontTokens.caption(context)` | `12.sp` | `14.sp` |
| `FontTokens.body(context)` | `14.sp` | `16.sp` |
| `FontTokens.title(context)` | `24.sp` | `20.sp` |

### ComponentTokens (con context)

| Token | Móvil Portrait | Móvil Landscape | Tablet Portrait | Tablet Landscape |
|---|---|---|---|---|
| `ComponentTokens.buttonHeight(context)` | `48.h` (M) | `36.h` (S) | `56.h` (L) | `48.h` (M) |
