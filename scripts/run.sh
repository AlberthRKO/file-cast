#!/usr/bin/env bash

# Ejecuta una variante Flutter con hot reload.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/config.sh
source "$SCRIPT_DIR/config.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

fail() {
    echo -e "${RED}Error: $*${NC}" >&2
    exit 1
}

show_help() {
    cat <<'EOF'
Uso:
  ./scripts/run.sh <flavor> [opciones]

Opciones:
  --debug                   Debug (por defecto)
  --profile                 Profile
  --release                 Release
  --device <id>             Dispositivo específico
  --base-url <url>          Override compilado de BASE_URL_FILE_CAST
  --auth-url <url>          Override compilado de BASE_URL_AUTH
  --help                    Mostrar esta ayuda
EOF
}

if [[ "${1:-}" == '--help' || "${1:-}" == '-h' ]]; then
    show_help
    exit 0
fi

[[ $# -ge 1 ]] || {
    show_help
    exit 1
}

REQUESTED_FLAVOR="$1"
shift
MODE='debug'
DEVICE=''
BASE_URL_OVERRIDE="${BASE_URL_FILE_CAST:-}"
AUTH_URL_OVERRIDE="${BASE_URL_AUTH:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            MODE='debug'
            shift
            ;;
        --profile)
            MODE='profile'
            shift
            ;;
        --release)
            MODE='release'
            shift
            ;;
        --device)
            [[ $# -ge 2 ]] || fail '--device requiere un id.'
            DEVICE="$2"
            shift 2
            ;;
        --base-url)
            [[ $# -ge 2 ]] || fail '--base-url requiere un valor.'
            BASE_URL_OVERRIDE="$2"
            shift 2
            ;;
        --auth-url)
            [[ $# -ge 2 ]] || fail '--auth-url requiere un valor.'
            AUTH_URL_OVERRIDE="$2"
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

RUN_ARGS=(
    '--flavor' "$FLAVOR"
    '--target' "$DART_TARGET"
)
if [[ "$MODE" != 'debug' ]]; then
    RUN_ARGS+=("--$MODE")
fi
if [[ -n "$BASE_URL_OVERRIDE" ]]; then
    RUN_ARGS+=("--dart-define=BASE_URL_FILE_CAST=$BASE_URL_OVERRIDE")
fi
if [[ -n "$AUTH_URL_OVERRIDE" ]]; then
    RUN_ARGS+=("--dart-define=BASE_URL_AUTH=$AUTH_URL_OVERRIDE")
fi
if [[ -n "$DEVICE" ]]; then
    RUN_ARGS+=( '--device-id' "$DEVICE" )
fi

echo -e "${GREEN}Ejecutando File Cast ($FLAVOR) en modo $MODE${NC}"
cd "$PROJECT_DIR"
flutter run "${RUN_ARGS[@]}"
