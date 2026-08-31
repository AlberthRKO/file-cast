# Estado y secuencia de migración Flutter

Este documento separa la migración incremental de vistas de la limpieza global. Debe actualizarse al terminar cada sesión. Los prompts ejecutables están en [SINGLE_VIEW_REFACTOR_PROMPT.md](SINGLE_VIEW_REFACTOR_PROMPT.md) y [RESTRUCTURING_PROMPT.md](RESTRUCTURING_PROMPT.md).

## Regla de operación

La unidad recomendada no es un archivo aislado sin contexto, sino una **vista y sus widgets directos**. Un widget compartido se migra cuando una vista migrada lo necesita. No se deben trasladar todos los archivos de `presentation/widgets` de forma masiva, porque muchos pertenecen a prototipos o módulos que quizá no formen parte del producto final.

Cada migración sigue este orden:

1. inspeccionar la vista, su ruta, proveedores, widgets directos y contratos;
2. crear o reutilizar modelos, repositorio, estado Freezed y ViewModel;
3. construir la View en `lib/ui/features/` usando constraints y el tema activo;
4. migrar su navegación a `go_router`;
5. cambiar la ruta solo cuando la nueva View esté completa;
6. conservar un adaptador temporal únicamente si tiene consumidores;
7. actualizar este tracker.

## Estado actual

| Orden | Vista o vertical | Estado | Destino esperado | Observaciones |
|---:|---|---|---|---|
| 1 | Home/listado de requisas | Migrada | `ui/features/requisitions/list` | MVVM, Freezed, tema, layout adaptive, filtros y carga progresiva. `presentation/pages/home/home.dart` no tiene consumidores detectados y queda como candidato de retiro controlado. |
| 2 | Started | Pendiente | `ui/features/onboarding/started` | Retirar composición por orientación y tamaños ScreenUtil. |
| 3 | Login | Pendiente | `ui/features/auth/login` | Separar formulario/autenticación; el redirect de sesión pertenece al router. |
| 4 | Offline | Pendiente | `ui/features/sync/offline` | Definir si es pantalla, estado transversal o destino persistente antes de crear shell. |
| 5 | Settings | Pendiente | `ui/features/settings` | Integrar preferencia de tema y configuración real; la vista actual está vacía. |
| 6 | Crear requisa | No implementada | `ui/features/requisitions/create` | Crear como vertical nueva; página en compact/altura compacta y diálogo limitado en medium+. |
| 7 | Detalle de requisa | No implementada | `ui/features/requisitions/detail` | Será el punto de entrada a evidencia y adquisición. |
| 8 | Lista/conexión USB | Pendiente | `ui/features/acquisition/connect` | Extraer orquestación de la View sin reescribir ADB/USB nativo. Requiere `requisitionId` y `sessionId`. |
| 9 | Mirror | Pendiente | `ui/features/acquisition/mirror` | Separar ciclo de vida, control y estados; conservar pipeline nativo. |
| 10 | Transferencia/evidencias | No implementada | `ui/features/acquisition/transfer` y `ui/features/evidence` | Implementar después de los contratos de requisa/sesión. |
| 11 | Shell adaptativo | Por decidir | `ui/core/navigation` + `ui/core/widgets` | Solo si existen al menos dos destinos persistentes reales. |
| 12 | Limpieza global | Bloqueada por migraciones | raíz/UI core | Ejecutar únicamente con el gate de retiro cumplido. |

## Deuda transversal conocida

- `lib/app.dart` todavía envuelve la app con `OrientationBuilder` y `ScreenUtilInit` por compatibilidad heredada.
- `lib/core/theme/app_dimensions.dart`, `app_text_styles.dart`, `app_tokens.dart` y tokens antiguos todavía dependen de ScreenUtil o de `BuildContext`.
- `AppSize.minTouchTarget` está actualmente en 45 dp; la guía establece 48 dp como objetivo mínimo de accesibilidad y debe revisarse con el propietario antes de la limpieza final.
- `lib/core/responsive/`, `lib/presentation/utils/responsive.dart` y extensiones responsive siguen teniendo consumidores.
- El router canónico todavía importa Started, Login, Offline, Settings, USB y Mirror desde `presentation/`.
- `lib/presentation/routes/` permanece como adaptador temporal.
- Existen numerosos widgets heredados. Solo se eliminan después de comprobar que no tienen consumidores.

## Gate para declarar una vista migrada

Una fila pasa a **Migrada** solo cuando:

- la ruta apunta a la nueva View;
- la lógica de negocio no está en widgets;
- estado/modelos nuevos usan Freezed cuando corresponde;
- no importa directa ni indirectamente ScreenUtil, `DeviceInfo`, `Responsive` o helpers legacy;
- no decide el árbol principal con orientación;
- usa el tema activo y no duplica paletas dentro de la feature;
- funciona conceptualmente en compact, medium, expanded, large y altura compacta;
- no usa `Navigator.push`, `MaterialPageRoute` ni mapas dinámicos como contrato;
- el código antiguo restante tiene un consumidor identificado o se retira.

## Gate para la limpieza global

El prompt final de [RESTRUCTURING_PROMPT.md](RESTRUCTURING_PROMPT.md) solo puede ejecutarse cuando:

1. todas las rutas de producto apunten a `lib/ui/features/`;
2. ninguna feature migrada importe `lib/presentation/`;
3. ningún archivo necesario importe ScreenUtil, helpers responsive antiguos o extensiones `.sw/.sh/.sp/.w/.h/.r`;
4. `app.dart` pueda retirar `ScreenUtilInit` sin romper consumidores;
5. el tema pueda usar tipografía y dimensiones lógicas;
6. `presentation/routes` no tenga consumidores;
7. todo archivo candidato a eliminación haya sido confirmado con búsqueda de referencias.

Si alguna condición falla, la sesión final debe informar el bloqueo y dejar el consumidor para una sesión dedicada; no debe ampliar el alcance ni forzar la eliminación.

## Validación del propietario

Los agentes no ejecutan tests, `flutter analyze`, `flutter run`, builds ni generadores. El propietario valida cada migración antes de cambiar la siguiente fila. El formateo y la inspección de búsquedas/diff sí están permitidos.
