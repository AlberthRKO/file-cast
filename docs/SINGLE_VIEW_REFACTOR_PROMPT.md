# Prompt para trabajar una View o feature

`AGENTS.md` y las skills contienen las reglas completas. En sesiones nuevas basta con indicar el alcance y el resultado esperado.

## Vista existente

```text
Refactoriza únicamente [FEATURE/VISTA] y sus widgets directos.

Sigue AGENTS.md y usa $flutter-apply-architecture-best-practices, $flutter-build-responsive-layout y $flutter-setup-declarative-routing. Conserva el diseño, tema, textos y comportamiento; aplica MVVM, Freezed cuando corresponda, constraints responsive y go_router. No introduzcas otro sistema responsive ni lógica de negocio en la View.

Compact: [COMPORTAMIENTO]. Medium: [COMPORTAMIENTO]. Expanded/Large: [COMPORTAMIENTO]. Con altura menor a 480, prioriza contenido, teclado y scroll sin decidir por orientación.

Modifica solo la vertical necesaria. No implementes backend ficticio ni ejecutes tests, analyze, build, run o generadores. Informa cambios y deuda restante.
```

## Feature nueva

```text
Implementa únicamente [FEATURE] en lib/ui/features/[DESTINO].

Sigue AGENTS.md y usa $flutter-apply-architecture-best-practices, $flutter-build-responsive-layout y $flutter-setup-declarative-routing. Crea View, ViewModel, estado Freezed y contratos de repositorio/servicio solo si el caso los necesita. Reutiliza tema, adaptive y widgets core existentes; no dupliques tokens ni inventes datos dentro de la View.

Registra la ruta declarativa [RUTA], con IDs de negocio en path parameters y fallback visible. Define el comportamiento compact/medium/expanded por espacio disponible y soporta vertical/horizontal y altura compacta.

No amplíes el alcance ni ejecutes tests, analyze, build, run o generadores.
```

## Corrección después de compilar

```text
Corrige únicamente los errores de compilación reportados para [FEATURE]. Sigue AGENTS.md, conserva su MVVM, tema, responsive y rutas, e inspecciona consumidores antes de cambiar APIs. No amplíes el alcance ni ejecutes validadores o generadores salvo autorización explícita.
```
