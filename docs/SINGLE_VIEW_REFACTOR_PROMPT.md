# Prompt para refactorizar una vista o archivo

Usar este prompt cuando el alcance sea una sola pantalla o un solo archivo. Sustituir los campos entre corchetes antes de enviarlo.

## Una vista completa

```text
Refactoriza únicamente la vista [RUTA_ACTUAL_DEL_ARCHIVO] y los widgets que utiliza directamente.

Antes de modificar código:

1. Lee AGENTS.md completo.
2. Lee docs/ARCHITECTURE_GUIDE.md, docs/RESPONSIVE_GUIDE.md y docs/ROUTING_GUIDE.md.
3. Usa y lee completamente:
   - $flutter-apply-architecture-best-practices
   - $flutter-build-responsive-layout
   - $flutter-setup-declarative-routing
4. Inspecciona sus dependencias, ruta actual y consumidores.
5. Preserva todos los cambios existentes del worktree.

Objetivo:

- Migra la pantalla a lib/ui/features/[FEATURE]/[SUBFEATURE]/.
- Crea una View pequeña, widgets de feature, estado inmutable y ViewModel.
- Usa Freezed para modelos y estados nuevos; crea sus fuentes y `part`, pero no ejecutes `build_runner` ni escribas generados manualmente.
- Mueve lógica de negocio, filtros, mocks, IO y coordinación fuera de la View.
- Si necesita datos temporales, utiliza un repositorio in-memory detrás de un contrato.
- Inyecta dependencias por constructor/provider en el scope apropiado.
- Usa únicamente lib/ui/core/adaptive y los tokens lógicos nuevos.
- No uses DeviceInfo, Responsive, ScreenUtil, .sw/.sh/.sp/.w/.h/.r ni OrientationBuilder.
- Decide variantes con LayoutBuilder y constraints disponibles.
- Compact: [COMPORTAMIENTO_COMPACT].
- Medium: [COMPORTAMIENTO_MEDIUM].
- Expanded/Large: [COMPORTAMIENTO_EXPANDED].
- Conserva la identidad visual y las acciones actuales.
- Migra su navegación a go_router usando una ruta declarativa y argumentos tipados.
- No uses Navigator.push, MaterialPageRoute ni Map<String,dynamic>.
- Cambia la ruta a la nueva View solo cuando su migración esté completa.
- Elimina únicamente código heredado que quede sin consumidores.
- No modifiques otras features ni USB/ADB/scrcpy.

Restricciones:

- No ejecutes tests, flutter analyze, flutter run, flutter build ni generadores.
- No agregues tests.
- Revisa el resultado únicamente por inspección del código y diff.

Entrega:

1. Archivos creados, modificados y retirados.
2. Responsabilidades movidas al ViewModel/repositorio.
3. Comportamiento adaptive de cada clase de ancho.
4. Ruta declarativa resultante.
5. Compatibilidad heredada que permanece.
6. Riesgos o trabajo pendiente para que yo lo valide.
7. Confirma que no ejecutaste tests, analyze ni compilación.
```

## Un archivo individual sin migrar toda la feature

```text
Refactoriza únicamente [RUTA_DEL_ARCHIVO]. No amplíes el alcance a una migración completa de la feature.

Lee AGENTS.md y las guías aplicables antes de editar. Inspecciona todos los consumidores del archivo.

Objetivo concreto: [DESCRIBIR_QUÉ_SE_DESEA_MEJORAR].

Reglas:

- Conserva su API pública siempre que no contradiga AGENTS.md.
- Si la API actual obliga a mantener lógica de negocio o responsive heredado, crea una API nueva y deja un adaptador temporal documentado.
- No introduzcas DeviceInfo, ScreenUtil, OrientationBuilder, Navigator.push ni Map<String,dynamic>.
- No muevas archivos no relacionados.
- No cambies el comportamiento visual o funcional salvo lo solicitado.
- Informa qué parte no puede quedar correctamente en MVVM sin migrar la ViewModel/repositorio de la feature.
- No ejecutes tests, analyze, build, run ni generadores; yo realizaré la validación.

Entrega un diff acotado, lista de consumidores actualizados y deuda pendiente.
```

## Ejemplo para Home/listado de requisas

```text
Refactoriza el Home/listado de requisas siguiendo AGENTS.md.

Migra la implementación a ui/features/requisitions/list, conserva home.dart solo como compatibilidad y usa MVVM + Freezed. Mueve el mock detrás de RequisitionRepository in-memory. Haz la vista adaptativa: cards y filtros en bottom sheet en compact/altura compacta, grid o lista en medium y tabla en expanded/large. Registra /requisitions con go_router.

No implementes backend, detalle, creación ni adquisición. No ejecutes tests, analyze, build, run ni generadores.
```
