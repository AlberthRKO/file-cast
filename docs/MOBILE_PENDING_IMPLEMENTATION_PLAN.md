# Plan de implementación móvil de File Cast

## Objetivo

Conectar la aplicación móvil con `ms-auth`, `file-cast-back` y `ms-files-v2`, conservando la arquitectura MVVM/repositorio, el funcionamiento offline y el cifrado FCE de evidencias. Este plan toma como referencia técnica el flujo de autenticación de `justicia_libre_app`, pero no incorpora su flujo de autenticación en dos pasos.

## Estado de partida

- El formulario de login y el `LoginViewModel` ya existen, pero usan `InMemoryAuthRepository`.
- `Http` ya puede adjuntar `Authorization: Bearer`, pero todavía no tiene un gestor real de sesión ni renovación integrada.
- Requisas, detalle y parte de la creación usan repositorios en memoria.
- La base local, el outbox y el cifrado FCE de evidencias ya están preparados para continuar con sincronización.
- El backend local de negocio se ejecuta en `http://localhost:3000`.

## Flujo objetivo

```text
LoginView
  -> LoginViewModel
  -> AuthRepository
  -> AuthSessionService
  -> file-cast-back /api/v1/auth/login
       (file-cast-back reenvía la operación a ms-auth)
       ├─ guarda accessToken y refreshToken en almacenamiento seguro
       └─ consulta file-cast-back /api/v1/auth/me
            -> UserEntity
                 -> AuthSessionController
                      -> router y funcionalidades protegidas

Petición autenticada
  -> Http agrega Bearer accessToken
  -> si recibe 401, solicita /api/v1/auth/refresh-token una sola vez
  -> guarda el nuevo par de tokens y reintenta la petición original
  -> si el refresh falla, limpia la sesión y vuelve al login
```

El login enviará `numeroDocumento`, `password`, `deviceId` y `aplicacion`. File Cast no ejecutará `/v1/auth/verificar-totp`; el acceso será directo según la configuración de `ms-auth`.

## Fases pendientes

### Fase 1 — Login y sesión real

1. Reemplazar `InMemoryAuthRepository` por un repositorio remoto.
2. Consumir `/api/v1/auth/login` y `/api/v1/auth/me`.
3. Persistir access token, refresh token y usuario en almacenamiento seguro/local apropiado.
4. Restaurar la sesión al iniciar la aplicación.
5. Implementar refresh preventivo/reactivo, exclusión de login/refresh del interceptor y reintento único ante `401`.
6. Implementar logout remoto best-effort y limpieza local.
7. Mantener el formulario actual y mapear errores de red, credenciales y servidor.

### Fase 2 — Configuración de entornos

1. Configurar la URL del backend de File Cast por flavor.
2. Mantener la URL de `ms-auth` en el backend; el móvil solo configura la URL de `file-cast-back`.
3. Documentar las direcciones para escritorio, simulador y emulador Android (`10.0.2.2` para acceder al host local desde Android Emulator).

### Fase 3 — Requisas remotas

1. Implementar repositorios remotos para listado y detalle.
2. Consumir `GET /api/v1/requisitions` y `GET /api/v1/requisitions/:id`.
3. Retirar fixtures de los ambientes reales y conservar dobles solo para pruebas/desarrollo controlado.
4. Mapear paginación, filtros, estados y errores al estado Freezed de cada ViewModel.

### Fase 4 — Creación y sesiones de adquisición

1. Crear requisas con `POST /api/v1/requisitions`.
2. Crear sesiones con `POST /api/v1/requisitions/:id/sessions`.
3. Completar sesiones con `POST /api/v1/requisitions/:id/sessions/:sessionId/complete`.
4. Reemplazar identificadores locales temporales por IDs del backend cuando exista conexión.
5. Mantener operaciones pendientes en SQLite cuando el dispositivo esté offline.

### Fase 5 — Casos y personas

1. Alinear búsquedas con `/api/v1/file-cast/casos/list` y `/api/v1/file-cast/persona/buscar`.
2. Permitir crear una requisa vinculada inicialmente a una persona o a un caso.
3. Permitir vincular posteriormente el caso definitivo, respetando la versión del agregado.

### Fase 6 — Evidencias y galería remota

1. Obtener evidencias desde `GET /api/v1/requisitions/:id/evidences` y el detalle.
2. Solicitar la URL de contenido de `ms-files-v2` usando el `msFileId` autorizado.
3. Descargar el FCE, descifrarlo localmente, verificar SHA-256/tamaño y mostrarlo en la galería.
4. Mantener el archivo local cifrado y eliminar temporales descifrados al terminar la vista o la operación.

### Fase 7 — Sincronización offline completa

1. Consumir `GET /api/v1/sync/changes` para cambios incrementales del usuario.
2. Enviar `POST /api/v1/sync/operations` desde el outbox.
3. Sincronizar requisas, vínculos de caso/persona, sesiones, evidencias y finalización.
4. Usar `clientOperationId` para idempotencia y `version` para conflictos.
5. Rehidratar SQLite después de aplicar respuestas confirmadas.

### Fase 8 — Validación

1. Pruebas unitarias de repositorio, gestor de sesión y ViewModel.
2. Pruebas de contrato del login, refresh, `/me` y logout con respuestas representativas de `ms-auth`.
3. Pruebas de expiración, pérdida de red, refresh concurrente y logout remoto.
4. Validación manual en dispositivo/emulador con backend local.
5. Ejecutar `dart format`, `flutter analyze`, `flutter test` y compilación con el SDK propietario del proyecto antes de integrar la rama.

## Alcance de esta rama

Esta rama implementa únicamente la Fase 1. No modifica todavía los repositorios de requisas, sesiones, galería, búsqueda ni sincronización.

## Decisiones de seguridad

- Los tokens se almacenan mediante `flutter_secure_storage`.
- Nunca se registran tokens, contraseñas, headers `Authorization` ni cuerpos sensibles.
- Login y refresh se excluyen del interceptor y no se reintentan automáticamente.
- El refresh se serializa para evitar varias renovaciones simultáneas.
- Un refresh inválido elimina la sesión local y requiere iniciar sesión nuevamente.
- Las evidencias continúan cifrándose en el móvil antes de llegar a `ms-files-v2`; esa integración queda fuera de esta fase.

## Contrato de autenticación usado por el móvil

La app consume la fachada local de `file-cast-back`, que a su vez integra
`ms-auth`:

| Operación | Método y ruta en File Cast | Propósito |
|---|---|---|
| Login | `POST /api/v1/auth/login` | Credenciales, dispositivo y aplicación `mp`. |
| Refresh | `POST /api/v1/auth/refresh-token` | Renueva el par de tokens. |
| Perfil | `GET /api/v1/auth/me` | Obtiene usuario, roles y permisos. |
| Logout | `POST /api/v1/auth/logout` | Cierra la sesión remota y local. |

En desarrollo, `Config.baseUrl` usa `http://localhost:3000` en escritorio y
simuladores iOS. En Android Emulator usa automáticamente
`http://10.0.2.2:3000`, que representa al equipo anfitrión. En un dispositivo
Android físico se debe indicar la IP accesible del equipo que ejecuta el
backend, por ejemplo:

```bash
flutter run --dart-define=BASE_URL_FILE_CAST=http://192.168.1.100:3000
```

La configuración de cleartext para `http` queda limitada al manifest de
`debug`; los flavors de staging y producción siguen usando HTTPS según su
configuración.
