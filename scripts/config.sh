#!/usr/bin/env bash

# Configuración compartida para build.sh, run.sh y Makefile.
#
# Los flavors actuales son variantes únicas. El proyecto todavía no tiene
# dimensiones Android separadas para cliente y entorno; por eso no se deben
# inventar combinaciones como cliente1-staging aquí.

FILE_CAST_FLAVORS=(development staging production cliente1 cliente2)

normalize_flavor() {
    case "${1:-}" in
        development|dev)
            printf '%s\n' 'development'
            ;;
        staging|stage)
            printf '%s\n' 'staging'
            ;;
        production|prod)
            printf '%s\n' 'production'
            ;;
        cliente1|client1)
            printf '%s\n' 'cliente1'
            ;;
        cliente2|client2)
            printf '%s\n' 'cliente2'
            ;;
        *)
            return 1
            ;;
    esac
}

get_flavor_config() {
    local requested_flavor="${1:-}"
    local normalized_flavor

    normalized_flavor="$(normalize_flavor "$requested_flavor")" || {
        echo "Error: flavor '$requested_flavor' no válido." >&2
        echo "Flavors válidos: ${FILE_CAST_FLAVORS[*]}" >&2
        return 1
    }

    FLAVOR="$normalized_flavor"
    DART_TARGET="lib/main_${FLAVOR}.dart"

    case "$FLAVOR" in
        development)
            FLAVOR_KIND='entorno'
            FLAVOR_LABEL='[DEV] File Cast'
            DEFAULT_BASE_URL='https://0dpchkdj-3000.brs.devtunnels.ms'
            DEFAULT_AUTH_URL='https://auth.dev.mp.gob.bo'
            ;;
        staging)
            FLAVOR_KIND='entorno'
            FLAVOR_LABEL='[STG] File Cast'
            DEFAULT_BASE_URL='https://staging-api.example.com'
            DEFAULT_AUTH_URL='https://auth.dev.mp.gob.bo'
            ;;
        production)
            FLAVOR_KIND='entorno'
            FLAVOR_LABEL='File Cast'
            DEFAULT_BASE_URL='https://api.example.com'
            DEFAULT_AUTH_URL='https://auth.dev.mp.gob.bo'
            ;;
        cliente1)
            FLAVOR_KIND='cliente'
            FLAVOR_LABEL='Cliente 1 File Cast'
            DEFAULT_BASE_URL='https://api-cliente1.example.com'
            DEFAULT_AUTH_URL='https://auth.dev.mp.gob.bo'
            ;;
        cliente2)
            FLAVOR_KIND='cliente'
            FLAVOR_LABEL='Cliente 2 File Cast'
            DEFAULT_BASE_URL='https://api-cliente2.example.com'
            DEFAULT_AUTH_URL='https://auth.dev.mp.gob.bo'
            ;;
    esac
}

show_flavor_config() {
    get_flavor_config "${1:-}" || return 1

    echo "Flavor: $FLAVOR"
    echo "Tipo: $FLAVOR_KIND"
    echo "Nombre visible Android/iOS: $FLAVOR_LABEL"
    echo "Target Dart: $DART_TARGET"
    echo "URL por defecto en Config.dart: $DEFAULT_BASE_URL"
    echo "URL auth por defecto en Config.dart: $DEFAULT_AUTH_URL"
    if [[ -n "${BASE_URL_FILE_CAST:-}" ]]; then
        echo "URL compilada por override: $BASE_URL_FILE_CAST"
    else
        echo "URL compilada por override: <ninguna; se usa Config.dart>"
    fi
    if [[ -n "${BASE_URL_AUTH:-}" ]]; then
        echo "URL auth compilada por override: $BASE_URL_AUTH"
    else
        echo "URL auth compilada por override: <ninguna; se usa Config.dart>"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "${1:-}" == "--all" ]]; then
        for flavor in "${FILE_CAST_FLAVORS[@]}"; do
            echo "--- $flavor ---"
            show_flavor_config "$flavor"
            echo
        done
    elif [[ $# -eq 1 ]]; then
        show_flavor_config "$1"
    else
        echo "Uso: $0 <flavor>"
        echo "     $0 --all"
        exit 1
    fi
fi
