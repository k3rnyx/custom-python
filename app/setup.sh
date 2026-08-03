#!/usr/bin/env bash

set -Eeuo pipefail

# Evita que una pregunta de debconf deje bloqueado el proceso en segundo plano.
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$PROJECT_DIR/.venv"

# En una simulación no debemos crear archivos ni acceder a la red.  El motor
# Python solo necesita InquirerPy para el menú interactivo; en modo dry-run
# puede usar el fallback de curses y ejecutarse con el Python del sistema.
DRY_RUN=0
for argumento in "$@"; do
    if [[ "$argumento" == "--dry-run" ]]; then
        DRY_RUN=1
        break
    fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    if ! command -v python3 >/dev/null 2>&1; then
        printf '\nError: --dry-run requiere python3 instalado.\n' >&2
        exit 1
    fi
    exec python3 "$SCRIPT_DIR/ubuntu_customizer.py" "$@"
fi

info() {
    printf '\n[ubuntu-customizer] %s\n' "$1"
}

if ! command -v python3 >/dev/null 2>&1; then
    info "Python 3 no está instalado. Se solicitarán permisos para instalarlo."
    if ! command -v sudo >/dev/null 2>&1; then
        printf '\nError: no se encontró sudo. Instala Python 3 con privilegios de administrador.\n' >&2
        exit 1
    fi
    sudo apt-get update
    sudo apt-get install -y python3 python3-venv python3-pip
elif ! python3 -m venv --help >/dev/null 2>&1; then
    info "Falta el módulo venv. Se instalará python3-venv."
    sudo apt-get update
    sudo apt-get install -y python3-venv python3-pip
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    info "Preparando el entorno aislado de Ubuntu Customizer."
    python3 -m venv "$VENV_DIR"
fi

info "Instalando dependencias del menú."
"$VENV_DIR/bin/python" -m pip install --disable-pip-version-check -r "$SCRIPT_DIR/requirements.txt"
printf '%s\n' '@@PROGRESS DONE Preparando entorno Python'

info "Iniciando Ubuntu Customizer."
exec "$VENV_DIR/bin/python" "$SCRIPT_DIR/ubuntu_customizer.py" "$@"
