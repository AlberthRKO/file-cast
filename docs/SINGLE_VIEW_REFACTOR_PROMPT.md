# Prompts directos para migrar una vista

Estos prompts están diseñados para nuevas sesiones sobre este repositorio. `AGENTS.md` y las guías contienen las reglas extensas, por lo que el prompt de trabajo puede ser corto.

Usar **una vista por sesión**. La unidad incluye el archivo de entrada, sus widgets directos, su ViewModel/estado y la actualización de su ruta. No combinar vistas sin solicitarlo expresamente.

## Prompt mínimo recomendado

Copiar, completar los cuatro campos y enviar:

```text
Migra únicamente [ARCHIVO_ACTUAL] y sus widgets directos a [DESTINO_FEATURE].

Sigue AGENTS.md, docs/MIGRATION_TRACKER.md y las guías del proyecto. Usa obligatoriamente $flutter-apply-architecture-best-practices, $flutter-build-responsive-layout y $flutter-setup-declarative-routing.

Conserva el diseño, tema, textos y comportamiento actual. Aplica MVVM + Freezed, constraints responsive y go_router. Compact: [COMPACT]. Medium: [MEDIUM]. Expanded/Large: [EXPANDED]. Altura menor a 480: prioriza contenido y scroll, sin decidir por orientación.

No reutilices responsive legacy ni agregues otro sistema. Cambia la ruta solo al completar la nueva View, conserva adaptadores con consumidores y actualiza docs/MIGRATION_TRACKER.md. No modifiques otras features ni ejecutes tests, analyze, build, run o generadores.
```

Este prompt ya implica:

- leer completamente `AGENTS.md` y documentos obligatorios;
- inspeccionar `git status`, ruta, providers y consumidores;
- usar `lib/ui/features`, `lib/ui/core/adaptive`, tokens lógicos y tema activo;
- no usar ScreenUtil, DeviceInfo, Responsive, OrientationBuilder, `.sw/.sh/.sp/.w/.h/.r`;
- mover negocio, mocks, filtrado, IO y coordinación fuera de la View;
- usar repositorios/servicios por constructor y estados Freezed;
- no usar `Navigator.push`, `MaterialPageRoute` ni `Map<String,dynamic>`;
- preservar USB/ADB/scrcpy salvo que la vista solicitada sea adquisición.

## Prompt para un widget aislado

Usarlo solo si no corresponde migrar toda la pantalla:

```text
Refactoriza únicamente [ARCHIVO_WIDGET] y actualiza solo sus consumidores directos.

Sigue AGENTS.md y docs/MIGRATION_TRACKER.md. Conserva su diseño/API cuando sea viable, usa ThemeData y constraints locales, y elimina responsive legacy del widget. Si su API obliga a mezclar provider, navegación o negocio, crea una API nueva y deja un adaptador temporal para consumidores no migrados.

No lo conviertas en widget global salvo que lo usen al menos dos features migradas. No ejecutes tests, analyze, build, run ni generadores. Informa consumidores actualizados y deuda restante.
```

## Prompts listos para las vistas actuales

### 1. Started

```text
Migra únicamente lib/presentation/pages/started/started.dart y sus widgets directos a lib/ui/features/onboarding/started/.

Sigue AGENTS.md y docs/MIGRATION_TRACKER.md. Usa las skills obligatorias de arquitectura, responsive y routing. Conserva el diseño actual. Compact: composición vertical scrollable. Medium+: contenido centrado o dos zonas limitadas. Altura menor a 480: reduce decoración y prioriza CTA. No uses ramas portrait/landscape, ScreenUtil ni DeviceInfo. Registra /started en el router canónico y actualiza el tracker.

No migres Login ni otras vistas. No ejecutes tests, analyze, build, run o generadores.
```

### 2. Login

```text
Migra únicamente lib/presentation/pages/login/login.dart y sus widgets directos a lib/ui/features/auth/login/.

Sigue AGENTS.md y docs/MIGRATION_TRACKER.md. Usa las skills obligatorias. Conserva tema y diseño. Crea LoginState/LoginViewModel con Freezed; formulario y autenticación salen de la View. Compact: formulario scrollable y ancho completo. Medium+: formulario centrado maxWidth 480–640 y decoración opcional. Altura menor a 480: ocultar decoración no esencial y respetar teclado. Registra /login; la sesión/redirect pertenece al router y la View no simula autenticación.

No migres Started ni implementes backend ficticio. No ejecutes tests, analyze, build, run o generadores.
```

### 3. Offline

```text
Migra únicamente lib/presentation/pages/offline/offline.dart y sus widgets directos a lib/ui/features/sync/offline/.

Sigue AGENTS.md y docs/MIGRATION_TRACKER.md. Usa las skills obligatorias. Primero determina por consumidores si Offline es ruta, estado transversal o ambos; no inventes un shell. Conserva diseño/tema y representa estados offline, sincronizando, error y recuperado mediante ViewModel Freezed. Compact: contenido vertical scrollable. Medium+: bloque centrado de ancho legible. Migra /offline a go_router y actualiza el tracker.

No implementes sincronización real ni modifiques otras features. No ejecutes tests, analyze, build, run o generadores.
```

### 4. Settings

```text
Migra únicamente lib/presentation/pages/settings/settings.dart y sus widgets directos a lib/ui/features/settings/.

Sigue AGENTS.md y docs/MIGRATION_TRACKER.md. Usa las skills obligatorias. Crea una View responsive y un ViewModel solo para preferencias reales existentes. Integra ThemeController sin duplicar paletas. Compact: lista/formulario vertical. Medium+: contenido centrado con maxWidth. Expanded/Large: no estirar controles; supporting pane solo si aporta información. Migra /settings a go_router y actualiza el tracker.

No inventes configuraciones ni crees shell salvo solicitud explícita. No ejecutes tests, analyze, build, run o generadores.
```

### 5. Crear requisa

```text
Implementa únicamente la vertical de crear requisa en lib/ui/features/requisitions/create/ siguiendo AGENTS.md, mockups y docs/MIGRATION_TRACKER.md. Usa las skills obligatorias.

Crea estado/ViewModel Freezed y usa RequisitionRepository; la View no crea mocks ni reglas. Compact o altura menor a 480: página full-screen scrollable con footer seguro. Medium+: diálogo/ruta con maxWidth 680, maxHeight limitado, cuerpo scrollable y footer separado. Conserva tema e inputs del proyecto. Registra /requisitions/new con go_router y actualiza el tracker.

No implementes backend, detalle o adquisición. No ejecutes tests, analyze, build, run o generadores.
```

### 6. Detalle de requisa

```text
Implementa únicamente el detalle en lib/ui/features/requisitions/detail/ siguiendo AGENTS.md, mockups y docs/MIGRATION_TRACKER.md. Usa las skills obligatorias.

Crea RequisitionDetailState/ViewModel Freezed y carga por requisitionId mediante repositorio. Compact: resumen, evidencia y acciones en una columna/tabs. Medium: grid o panel de apoyo si hay altura. Expanded/Large con altura regular: dos paneles limitados. Acciones dependen del estado/capacidades; no contienen lógica falsa en la View. Registra /requisitions/:requisitionId y actualiza el tracker.

No implementes todavía protocolo USB ni backend. No ejecutes tests, analyze, build, run o generadores.
```

### 7. Conexión USB

```text
Migra únicamente lib/presentation/pages/presentation/mirror/usb_device_list_page.dart y sus widgets directos a lib/ui/features/acquisition/connect/.

Sigue AGENTS.md, documentos de adquisición y docs/MIGRATION_TRACKER.md. Usa las skills obligatorias. Extrae estado/orquestación de la View hacia AcquisitionConnectViewModel y servicios/adaptadores, pero conserva sin reescribir el protocolo USB/ADB nativo. Toda sesión recibe requisitionId y sessionId. Compact/altura compacta: flujo vertical scrollable y diagnóstico secundario colapsable. Medium+: pasos y diagnóstico distribuidos por constraints. Migra la ruta jerárquica con go_router, argumentos tipados y cleanup idempotente; actualiza el tracker.

No implementes captura, grabación o transferencia en esta sesión. No ejecutes tests, analyze, build, run o generadores.
```

### 8. Mirror

```text
Migra únicamente lib/presentation/pages/presentation/mirror/mirror_page.dart y sus widgets directos a lib/ui/features/acquisition/mirror/.

Sigue AGENTS.md, documentos de adquisición y docs/MIGRATION_TRACKER.md. Usa las skills obligatorias. Conserva decoder/control nativo y mueve ciclo de vida/comandos a ViewModel/servicios. La ruta incluye requisitionId y sessionId; handles efímeros usan un argumento tipado con fallback. Compact: mirror principal y controles persistentes, evidencia secundaria en tab/bottom sheet. Medium: composición según ancho y altura. Expanded/Large con altura regular: mirror + panel de evidencias. Calcula aspect-fit y coordenadas con LayoutBuilder; cleanup idempotente al salir. Actualiza el tracker.

No reescribas ADB/scrcpy ni implementes transferencia. No ejecutes tests, analyze, build, run o generadores.
```

## Prompt de corrección posterior

Después de que el propietario compile una vista y entregue errores:

```text
Corrige únicamente los errores reportados de la última vista migrada. Lee AGENTS.md y conserva su arquitectura, responsive, tema y ruta. No amplíes el alcance ni sustituyas Freezed por clases manuales. Inspecciona el error y sus consumidores; modifica solo lo necesario. Ejecuta analyze/build/tests/generadores únicamente si te lo autorizo expresamente en este mensaje.
```

## Entrega obligatoria de cada sesión

La respuesta debe indicar:

1. vista/ruta migrada;
2. archivos creados, modificados y retirados;
3. lógica movida al ViewModel/repositorio;
4. comportamiento compact/medium/expanded/altura compacta;
5. imports/rutas legacy retirados y compatibilidad que permanece;
6. fila actualizada en `MIGRATION_TRACKER.md`;
7. validación que debe realizar el propietario;
8. confirmación de que no se ejecutaron comandos prohibidos.
