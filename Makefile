.PHONY: help apk apk-split apk-ofuscacion apk-split-ofuscacion \
        appbundle android ios run show-config all-apk-split \
        all-apk-ofuscacion all-apk-split-ofuscacion \
        development-apk development-apk-split development-apk-ofuscacion \
        development-apk-split-ofuscacion development-appbundle development-ios \
        staging-apk staging-apk-split staging-apk-ofuscacion \
        staging-apk-split-ofuscacion staging-appbundle staging-ios \
        production-apk production-apk-split production-apk-ofuscacion \
        production-apk-split-ofuscacion production-appbundle production-ios \
        cliente1-apk cliente1-apk-split cliente1-apk-ofuscacion \
        cliente1-apk-split-ofuscacion cliente1-appbundle cliente1-ios \
        cliente2-apk cliente2-apk-split cliente2-apk-ofuscacion \
        cliente2-apk-split-ofuscacion cliente2-appbundle cliente2-ios \
        dev-apk dev-apk-split dev-apk-ofuscacion dev-apk-split-ofuscacion \
        stage-apk stage-apk-split stage-apk-ofuscacion stage-apk-split-ofuscacion \
        prod-apk prod-apk-split prod-apk-ofuscacion prod-apk-split-ofuscacion

SHELL := /bin/bash

FLAVOR ?= development
MODE ?= release
BASE_URL_FILE_CAST ?=
BASE_URL_AUTH ?=
DEVICE ?=

export BASE_URL_FILE_CAST BASE_URL_AUTH

help: ## Mostrar los comandos disponibles
	@echo "Uso genérico:"
	@echo "  make apk FLAVOR=production MODE=release"
	@echo "  make apk-split FLAVOR=cliente1"
	@echo "  make apk-ofuscacion FLAVOR=production"
	@echo "  make apk-split-ofuscacion FLAVOR=production"
	@echo "  make appbundle FLAVOR=production"
	@echo "  make run FLAVOR=staging MODE=debug DEVICE=<id>"
	@echo ""
	@echo "Targets por flavor:"
	@echo "  <flavor>-apk"
	@echo "  <flavor>-apk-split"
	@echo "  <flavor>-apk-ofuscacion"
	@echo "  <flavor>-apk-split-ofuscacion"
	@echo "  <flavor>-appbundle"
	@echo "  <flavor>-ios"
	@echo ""
	@echo "Atajos: dev-*, stage-* y prod-*"
	@echo ""
	@echo "Opcionales: BASE_URL_FILE_CAST=https://... y BASE_URL_AUTH=https://... para compilar overrides."

apk: ## Compilar APK. Variables: FLAVOR, MODE, BASE_URL_FILE_CAST, BASE_URL_AUTH
	@./scripts/build.sh "$(FLAVOR)" apk --$(MODE)

apk-split: ## Compilar APKs separados por ABI
	@./scripts/build.sh "$(FLAVOR)" apk --$(MODE) --split-per-abi

apk-ofuscacion: ## Compilar APK con ofuscación Dart
	@./scripts/build.sh "$(FLAVOR)" apk --$(MODE) --obfuscate

apk-split-ofuscacion: ## Compilar APKs por ABI con ofuscación Dart
	@./scripts/build.sh "$(FLAVOR)" apk --$(MODE) --split-per-abi --obfuscate

appbundle: ## Compilar Android App Bundle (AAB)
	@./scripts/build.sh "$(FLAVOR)" appbundle --$(MODE)

android: appbundle ## Alias de appbundle

ios: ## Compilar iOS
	@./scripts/build.sh "$(FLAVOR)" ios --$(MODE)

run: ## Ejecutar con hot reload. Variables: FLAVOR, MODE, DEVICE
	@if [[ -n "$(DEVICE)" ]]; then \
		./scripts/run.sh "$(FLAVOR)" --$(MODE) --device "$(DEVICE)"; \
	else \
		./scripts/run.sh "$(FLAVOR)" --$(MODE); \
	fi

show-config: ## Mostrar la configuración efectiva de un flavor
	@./scripts/config.sh "$(FLAVOR)"

define DEFINE_FLAVOR_TARGETS
$(1)-apk:
	@./scripts/build.sh "$(1)" apk --$(MODE)
$(1)-apk-split:
	@./scripts/build.sh "$(1)" apk --$(MODE) --split-per-abi
$(1)-apk-ofuscacion:
	@./scripts/build.sh "$(1)" apk --$(MODE) --obfuscate
$(1)-apk-split-ofuscacion:
	@./scripts/build.sh "$(1)" apk --$(MODE) --split-per-abi --obfuscate
$(1)-appbundle:
	@./scripts/build.sh "$(1)" appbundle --$(MODE)
$(1)-ios:
	@./scripts/build.sh "$(1)" ios --$(MODE)
endef

$(foreach flavor,development staging production cliente1 cliente2,$(eval $(call DEFINE_FLAVOR_TARGETS,$(flavor))))

dev-apk: development-apk
dev-apk-split: development-apk-split
dev-apk-ofuscacion: development-apk-ofuscacion
dev-apk-split-ofuscacion: development-apk-split-ofuscacion
stage-apk: staging-apk
stage-apk-split: staging-apk-split
stage-apk-ofuscacion: staging-apk-ofuscacion
stage-apk-split-ofuscacion: staging-apk-split-ofuscacion
prod-apk: production-apk
prod-apk-split: production-apk-split
prod-apk-ofuscacion: production-apk-ofuscacion
prod-apk-split-ofuscacion: production-apk-split-ofuscacion

all-apk-split: development-apk-split staging-apk-split production-apk-split cliente1-apk-split cliente2-apk-split
all-apk-ofuscacion: development-apk-ofuscacion staging-apk-ofuscacion production-apk-ofuscacion cliente1-apk-ofuscacion cliente2-apk-ofuscacion
all-apk-split-ofuscacion: development-apk-split-ofuscacion staging-apk-split-ofuscacion production-apk-split-ofuscacion cliente1-apk-split-ofuscacion cliente2-apk-split-ofuscacion
