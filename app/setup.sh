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

if ! command -v apt-get >/dev/null 2>&1; then
    printf '\nError: este instalador requiere apt-get (Ubuntu/Debian).\n' >&2
    exit 1
fi

APT_PREFIX=()
if [[ "$EUID" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        printf '\nError: se requiere sudo para instalar dependencias.\n' >&2
        exit 1
    fi
    APT_PREFIX=(sudo)
fi

# Se instalan antes de iniciar el menú para que cualquier perfil pueda
# ejecutarse inmediatamente después de seleccionar una opción.
DEPENDENCIAS_SISTEMA=(
    python3 python3-pip python3-venv
    git gnome-shell gnome-shell-extensions gnome-shell-ubuntu-extensions
    gnome-shell-extension-manager gnome-tweaks sassc gtk2-engines-murrine
    gnome-themes-extra dconf-cli zsh curl fontconfig fzf tmux
    direnv ripgrep fd-find bat jq deepin-icon-theme papirus-icon-theme
    libglib2.0-bin
    nodejs npm postgresql-client redis-tools docker.io docker-compose-v2
    build-essential
    nmap wireshark tshark tcpdump netcat-openbsd dnsutils whois traceroute
    openssl gnupg ufw auditd lynis clamav lsof strace gdb yara
)

paquete_instalado() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'
}

dependencia_cubierta() {
    case "$1" in
        docker-compose-v2) paquete_instalado docker-compose-plugin ;;
        *) return 1 ;;
    esac
}

DEPENDENCIAS_FALTANTES=()
for paquete in "${DEPENDENCIAS_SISTEMA[@]}"; do
    if paquete_instalado "$paquete"; then
        continue
    fi
    if dependencia_cubierta "$paquete"; then
        printf '[ubuntu-customizer] Dependencia cubierta: %s\n' "$paquete"
        continue
    fi
    DEPENDENCIAS_FALTANTES+=("$paquete")
done

info "Instalando dependencias del sistema antes del menú."
if [[ "${#DEPENDENCIAS_FALTANTES[@]}" -gt 0 ]]; then
    "${APT_PREFIX[@]}" apt-get update
    "${APT_PREFIX[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "${DEPENDENCIAS_FALTANTES[@]}"
else
    printf '%s\n' '[ubuntu-customizer] Todas las dependencias del sistema ya están instaladas.'
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    info "Preparando el entorno aislado de Ubuntu Customizer."
    python3 -m venv "$VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" -m pip --version >/dev/null 2>&1; then
    printf '\nError: el entorno Python se creó sin pip. Verifica python3-venv y vuelve a ejecutar el script.\n' >&2
    exit 1
fi

info "Instalando dependencias del menú."
"$VENV_DIR/bin/python" -m pip install --disable-pip-version-check -r "$SCRIPT_DIR/requirements.txt"
printf '%s\n' '@@PROGRESS DONE Preparando entorno Python'

info "Iniciando Ubuntu Customizer."
exec "$VENV_DIR/bin/python" "$SCRIPT_DIR/ubuntu_customizer.py" "$@"
