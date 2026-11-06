# Flavors y compilación de File Cast

File Cast usa flavors nativos de Android/iOS y un entrypoint Dart por variante,
siguiendo el esquema del artículo de referencia:

```text
flutter build apk \
  --flavor <flavor> \
  --target lib/main_<flavor>.dart \
  --release
```

## Variantes actuales

| Flavor | Tipo | Target Dart | Android applicationId | iOS bundle id | Nombre visible |
| --- | --- | --- | --- | --- | --- |
| `development` | entorno | `lib/main_development.dart` | `com.fiscalia.file_cast.dev` | `com.fiscalia.file-cast.dev` | `[DEV] File Cast` |
| `staging` | entorno | `lib/main_staging.dart` | `com.fiscalia.file_cast.stg` | `com.fiscalia.file-cast.stg` | `[STG] File Cast` |
| `production` | entorno | `lib/main_production.dart` | `com.fiscalia.file_cast` | `com.fiscalia.file-cast` | `File Cast` |
| `cliente1` | cliente | `lib/main_cliente1.dart` | `com.fiscalia.file_cast.cliente1` | `com.fiscalia.file-cast.cliente1` | `Cliente 1 File Cast` |
| `cliente2` | cliente | `lib/main_cliente2.dart` | `com.fiscalia.file_cast.cliente2` | `com.fiscalia.file-cast.cliente2` | `Cliente 2 File Cast` |

Las configuraciones iOS equivalentes ya existen como `Debug-<flavor>`,
`Profile-<flavor>` y `Release-<flavor>`, y los schemes compartidos tienen los
mismos nombres de flavor.

## Makefile

El comando recomendado para una APK release separada por arquitectura es:

```bash
make production-apk-split
```

También se pueden usar los targets genéricos:

```bash
make apk FLAVOR=development MODE=debug
make apk-split FLAVOR=cliente1
make apk-ofuscacion FLAVOR=production
make apk-split-ofuscacion FLAVOR=production
make appbundle FLAVOR=production
make ios FLAVOR=cliente2
make run FLAVOR=staging MODE=debug DEVICE=<device-id>
```

Para cada flavor también existen los targets explícitos. Por ejemplo:

```bash
make production-apk
make production-apk-split
make production-apk-ofuscacion
make production-apk-split-ofuscacion
```

Los atajos equivalentes son `dev-*`, `stage-*` y `prod-*`.

Atajos disponibles: `dev-*`, `stage-*` y `prod-*`. Para ver la configuración
resuelta de un flavor:

```bash
make show-config FLAVOR=cliente1
```

## APK por ABI

`--split-per-abi` genera tres APKs para las arquitecturas soportadas por Flutter:

```text
build/app/outputs/flutter-apk/app-armeabi-v7a-*.apk
build/app/outputs/flutter-apk/app-arm64-v8a-*.apk
build/app/outputs/flutter-apk/app-x86_64-*.apk
```

El `*` incluye el flavor y el modo, por ejemplo `production-release`. Para
Google Play se recomienda `make production-appbundle`; para distribución
directa o instalación controlada, `make production-apk-split` reduce el tamaño
descargado por dispositivo.

## URL del backend

`Config.dart` mantiene los valores por defecto actuales. Si un entorno necesita
un endpoint distinto sin editar código:

```bash
BASE_URL_FILE_CAST=https://api.example.test make staging-apk-split
```

El valor se compila mediante `--dart-define=BASE_URL_FILE_CAST=...`.

## URL del microservicio de autenticación

La autenticación usa el microservicio público separado. Su valor por defecto es
https://auth.dev.mp.gob.bo y puede reemplazarse al compilar con
BASE_URL_AUTH o con la opción --auth-url de los scripts.

## Firma y ofuscación

Las builds Android release usan la configuración existente de
`android/app/build.gradle.kts`. Se puede usar `android/key.properties` (no se
versiona) o estas variables de entorno:

```text
ANDROID_KEYSTORE_PATH
ANDROID_KEYSTORE_ALIAS
ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD
ANDROID_KEYSTORE_PASSWORD
```

Para ofuscar Dart y conservar símbolos separados por flavor:

```bash
./scripts/build.sh production apk --split-per-abi --obfuscate
```

Los símbolos quedan en `artifacts/symbols/` y esa carpeta está ignorada por Git.

## Límite actual: entorno y cliente no son dimensiones combinables

La configuración actual tiene una sola dimensión Android llamada `default`.
Por tanto, `cliente1` y `staging` son variantes independientes; hoy no existe
`cliente1-staging` ni `cliente2-production` como flavor nativo. El Makefile
refleja exactamente esta configuración y no inventa esas combinaciones.

Si el producto necesita una matriz cliente × entorno, habrá que migrar Android
a dos dimensiones y crear los entrypoints/configuración Dart y schemes iOS
correspondientes antes de añadir targets como `cliente1-staging-apk`.
