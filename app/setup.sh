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
    direnv ripgrep fd-find bat jq zoxide eza btop tealdeer neovim shellcheck shfmt
    deepin-icon-theme papirus-icon-theme
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

instalar_aplicaciones() {
    local arquitectura identificador_vscode archivo_vscode directorio_temporal archivo_opencode
    arquitectura="$(dpkg --print-architecture)"

    info "Instalando aplicaciones de desarrollo."

    if ! command -v code >/dev/null 2>&1; then
        case "$arquitectura" in
            amd64) identificador_vscode='linux-deb-x64' ;;
            arm64) identificador_vscode='linux-deb-arm64' ;;
            armhf) identificador_vscode='linux-deb-armhf' ;;
            *)
                printf '[ubuntu-customizer] VS Code no tiene paquete compatible con %s; se omite.\n' \
                    "$arquitectura"
                identificador_vscode=''
                ;;
        esac

        if [[ -n "$identificador_vscode" ]]; then
            archivo_vscode="$(mktemp --suffix=.deb)"
            curl -fL --retry 3 \
                "https://update.code.visualstudio.com/latest/${identificador_vscode}/stable" \
                -o "$archivo_vscode"
            "${APT_PREFIX[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "$archivo_vscode"
            rm -f -- "$archivo_vscode"
        fi
    else
        printf '%s\n' '[ubuntu-customizer] VS Code ya está instalado.'
    fi

    if [[ ! -x "$HOME/.local/bin/firefox-nightly" ]]; then
        directorio_temporal="$(mktemp -d)"
        case "$arquitectura" in
            amd64) archivo_opencode='linux64' ;;
            arm64) archivo_opencode='linux64-aarch64' ;;
            *) archivo_opencode='' ;;
        esac
        if [[ -n "$archivo_opencode" ]]; then
            curl -fL --retry 3 \
                "https://download.mozilla.org/?product=firefox-nightly-latest-ssl&os=${archivo_opencode}&lang=en-US" \
                -o "$directorio_temporal/firefox-nightly.archive"
            mkdir -p "$HOME/.local/opt" "$HOME/.local/bin" "$HOME/.local/share/applications"
            # Mozilla puede publicar Nightly como tar.bz2 o tar.xz; tar detecta
            # automáticamente la compresión cuando no se fuerza un formato.
            tar -xf "$directorio_temporal/firefox-nightly.archive" -C "$directorio_temporal"
            if [[ ! -e "$HOME/.local/opt/firefox-nightly" ]]; then
                mv "$directorio_temporal/firefox" "$HOME/.local/opt/firefox-nightly"
            fi
            ln -sfn "$HOME/.local/opt/firefox-nightly/firefox" "$HOME/.local/bin/firefox-nightly"
            cat > "$HOME/.local/share/applications/firefox-nightly.desktop" <<EOF
[Desktop Entry]
Name=Firefox Nightly
Comment=Firefox Nightly
Exec=$HOME/.local/bin/firefox-nightly %u
Icon=$HOME/.local/opt/firefox-nightly/browser/chrome/icons/default/default128.png
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
EOF
        else
            printf '[ubuntu-customizer] Firefox Nightly no tiene binario compatible con %s; se omite.\n' \
                "$arquitectura"
        fi
        rm -rf -- "$directorio_temporal"
    else
        printf '%s\n' '[ubuntu-customizer] Firefox Nightly ya está instalado.'
    fi

    if ! command -v opencode >/dev/null 2>&1 \
        && [[ ! -x "$HOME/.opencode/bin/opencode" ]] \
        && [[ ! -x "$HOME/.local/bin/opencode" ]]; then
        archivo_opencode="$(mktemp)"
        curl -fsSL --retry 3 https://opencode.ai/install -o "$archivo_opencode"
        bash "$archivo_opencode"
        rm -f -- "$archivo_opencode"
    else
        printf '%s\n' '[ubuntu-customizer] OpenCode ya está instalado.'
    fi
}

normalizar_repositorio_mozilla() {
    local lista='/etc/apt/sources.list.d/mozilla.list'
    local formato='/etc/apt/sources.list.d/mozilla.sources'
    local respaldo="${lista}.disabled-by-ubuntu-customizer"

    # APT acepta cualquiera de los dos formatos, pero no ambos para el mismo
    # repositorio. Se conserva el formato .sources y se renombra el duplicado
    # para que pueda restaurarse manualmente si fuera necesario.
    if [[ -f "$lista" && -f "$formato" ]] \
        && grep -Fq 'packages.mozilla.org/apt' "$lista" \
        && grep -Fq 'packages.mozilla.org/apt' "$formato"; then
        if [[ -e "$respaldo" ]]; then
            respaldo="${lista}.disabled-by-ubuntu-customizer.$$"
        fi
        printf '[ubuntu-customizer] Repositorio Mozilla duplicado; se conserva %s y se renombra %s.\n' \
            "$formato" "$lista"
        "${APT_PREFIX[@]}" mv "$lista" "$respaldo"
    fi
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
normalizar_repositorio_mozilla
if [[ "${#DEPENDENCIAS_FALTANTES[@]}" -gt 0 ]]; then
    "${APT_PREFIX[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "${DEPENDENCIAS_FALTANTES[@]}"
else
    printf '%s\n' '[ubuntu-customizer] Todas las dependencias del sistema ya están instaladas.'
fi

printf '%s\n' '@@PROGRESS START Aplicaciones de desarrollo'
instalar_aplicaciones
printf '%s\n' '@@PROGRESS DONE Aplicaciones de desarrollo'

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
