#!/usr/bin/env bash

# Compila una variante Flutter de File Cast.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/config.sh
source "$SCRIPT_DIR/config.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

fail() {
    echo -e "${RED}Error: $*${NC}" >&2
    exit 1
}

show_help() {
    cat <<'EOF'
Uso:
  ./scripts/build.sh <flavor> <plataforma> [opciones]

Flavors:
  development | dev
  staging     | stage
  production  | prod
  cliente1    | client1
  cliente2    | client2

Plataformas:
  apk       APK de Android
  appbundle AAB de Android
  android   Alias de appbundle
  ios       App para iOS

Opciones:
  --release                 Release (por defecto)
  --debug                   Debug
  --profile                 Profile
  --split-per-abi           APK separado para armeabi-v7a, arm64-v8a y x86_64
  --obfuscate               Ofusca Dart y guarda símbolos en artifacts/symbols
  --base-url <url>          Override compilado de BASE_URL_FILE_CAST
  --help                    Mostrar esta ayuda

Ejemplos:
  ./scripts/build.sh development apk --debug
  ./scripts/build.sh production appbundle
  ./scripts/build.sh cliente1 apk --split-per-abi
  ./scripts/build.sh staging apk --release --base-url https://staging.example
EOF
}

[[ $# -ge 2 ]] || {
    show_help
    exit 1
}

REQUESTED_FLAVOR="$1"
PLATFORM="$2"
shift 2

MODE='release'
SPLIT_PER_ABI=false
OBFUSCATE=false
BASE_URL_OVERRIDE="${BASE_URL_FILE_CAST:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)
            MODE='release'
            shift
            ;;
        --debug)
            MODE='debug'
            shift
            ;;
        --profile)
            MODE='profile'
            shift
            ;;
        --split-per-abi)
            SPLIT_PER_ABI=true
            shift
            ;;
        --obfuscate)
            OBFUSCATE=true
            shift
            ;;
        --base-url)
            [[ $# -ge 2 ]] || fail "--base-url requiere un valor."
            BASE_URL_OVERRIDE="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            fail "opción desconocida: $1"
            ;;
    esac
done

get_flavor_config "$REQUESTED_FLAVOR"

[[ -f "$PROJECT_DIR/$DART_TARGET" ]] ||
    fail "no existe el entrypoint Dart esperado: $DART_TARGET"

case "$PLATFORM" in
    android|appbundle)
        PLATFORM='appbundle'
        ;;
    apk|ios)
        ;;
    *)
        fail "plataforma '$PLATFORM' no válida. Usa apk, appbundle, android o ios."
        ;;
esac

if [[ "$SPLIT_PER_ABI" == true && "$PLATFORM" != 'apk' ]]; then
    fail '--split-per-abi solo aplica a la plataforma apk.'
fi

if [[ "$OBFUSCATE" == true && "$MODE" != 'release' ]]; then
    fail '--obfuscate solo puede usarse con --release.'
fi

OBFUSCATION_ARGS=()
SYMBOLS_DIR=''
if [[ "$OBFUSCATE" == true ]]; then
    APP_VERSION="$(awk '/^version:/ { print $2; exit }' "$PROJECT_DIR/pubspec.yaml")"
    APP_VERSION="${APP_VERSION:-unknown}"
    SYMBOLS_DIR="$PROJECT_DIR/artifacts/symbols/$FLAVOR/$APP_VERSION/$PLATFORM"
    mkdir -p "$SYMBOLS_DIR"
    OBFUSCATION_ARGS=(
        '--obfuscate'
        "--split-debug-info=$SYMBOLS_DIR"
    )
fi

echo -e "${GREEN}Compilando File Cast${NC}"
echo -e "${YELLOW}Flavor: $FLAVOR ($FLAVOR_KIND)${NC}"
echo -e "${YELLOW}Target: $DART_TARGET${NC}"
echo -e "${YELLOW}Plataforma: $PLATFORM${NC}"
echo -e "${YELLOW}Modo: $MODE${NC}"
if [[ "$PLATFORM" == 'apk' ]]; then
    echo -e "${YELLOW}Split por ABI: $SPLIT_PER_ABI${NC}"
fi
if [[ -n "$BASE_URL_OVERRIDE" ]]; then
    echo -e "${YELLOW}BASE_URL_FILE_CAST: override compilado${NC}"
fi
if [[ -n "$SYMBOLS_DIR" ]]; then
    echo -e "${YELLOW}Símbolos Dart: $SYMBOLS_DIR${NC}"
fi

if [[ "$MODE" == 'release' && "$PLATFORM" != 'ios' ]]; then
    if [[ ! -f "$PROJECT_DIR/android/key.properties" &&
        -z "${ANDROID_KEYSTORE_PATH:-}" ]]; then
        echo -e "${YELLOW}Aviso: no se detectó android/key.properties ni ANDROID_KEYSTORE_PATH;${NC}"
        echo -e "${YELLOW}la build release necesita una configuración de firma válida.${NC}"
    fi
fi

COMMON_ARGS=(
    '--flavor' "$FLAVOR"
    '--target' "$DART_TARGET"
    "--$MODE"
)
if [[ -n "$BASE_URL_OVERRIDE" ]]; then
    COMMON_ARGS+=("--dart-define=BASE_URL_FILE_CAST=$BASE_URL_OVERRIDE")
fi
if [[ "$OBFUSCATE" == true ]]; then
    COMMON_ARGS+=("${OBFUSCATION_ARGS[@]}")
fi

case "$PLATFORM" in
    apk)
        BUILD_ARGS=("${COMMON_ARGS[@]}")
        if [[ "$SPLIT_PER_ABI" == true ]]; then
            BUILD_ARGS+=('--split-per-abi')
        fi
        cd "$PROJECT_DIR"
        flutter build apk "${BUILD_ARGS[@]}"
        OUTPUT_DIR="$PROJECT_DIR/build/app/outputs/flutter-apk"
        ;;
    appbundle)
        cd "$PROJECT_DIR"
        flutter build appbundle "${COMMON_ARGS[@]}"
        OUTPUT_DIR="$PROJECT_DIR/build/app/outputs/bundle"
        ;;
    ios)
        cd "$PROJECT_DIR"
        flutter build ios "${COMMON_ARGS[@]}"
        OUTPUT_DIR="$PROJECT_DIR/build/ios/iphoneos"
        ;;
esac

echo -e "${GREEN}Compilación completada.${NC}"
if [[ -d "$OUTPUT_DIR" ]]; then
    echo -e "${YELLOW}Artefactos encontrados en: $OUTPUT_DIR${NC}"
    find "$OUTPUT_DIR" \( \
        -type f \( -name '*.apk' -o -name '*.aab' -o -name '*.ipa' \) \
        -o -type d -name '*.app' \
    \) -print | sort
else
    echo -e "${YELLOW}Revisa los artefactos generados por Flutter en build/.${NC}"
fi
