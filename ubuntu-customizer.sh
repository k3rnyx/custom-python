#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PYTHON_INSTALLER="$SCRIPT_DIR/app/setup.sh"

source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/banner.sh"

# El banner original usa todo el ancho disponible de la terminal.
refresh_terminal_size
BANNER_HEIGHT=18

MENU_LABELS=(
    "Perfil WanTher — Fullstack Angular"
    "Perfil K3rNyx — Seguridad informática"
    "Ver configuración actual"
    "Salir"
)
MENU_DESCRIPTIONS=(
    "Angular, Node.js, pnpm, Docker, PostgreSQL y Redis"
    "Nmap, Wireshark, auditoría, red y laboratorios"
    "Muestra el estado visual actual del escritorio"
    "Cerrar Ubuntu Customizer"
)
MENU_INDEX=0
BANNER_FILE="${TMPDIR:-/tmp}/ubuntu-customizer-banner-$$.ansi"
BANNER_LINES=0
MENU_START=0
MENU_PADDING=60
DRY_RUN=0
ACTION=menu
PROFILE=wanther

log_info() { printf '  %b◆%b  %b%s%b\n' "$TN_CYAN" "$RST" "$TN_FG" "$*" "$RST"; }
log_error() { printf '  %b✗%b  %b%s%b\n' "$TN_PINK" "$RST" "$TN_FG" "$*" "$RST" >&2; }

pad_banner_height() {
    local source_file="$1" target_file="$2"
    local lines source_line index
    lines=$(wc -l < "$source_file")
    : > "$target_file"

    if ((lines > BANNER_HEIGHT)); then
        # Reduce verticalmente conservando toda la composición del banner.
        for ((index = 0; index < BANNER_HEIGHT; index += 1)); do
            source_line=$((1 + index * (lines - 1) / (BANNER_HEIGHT - 1)))
            sed -n "${source_line}p" "$source_file" >> "$target_file"
        done
        return 0
    fi

    cat "$source_file" > "$target_file"
    while ((lines < BANNER_HEIGHT)); do
        printf '\n' >> "$target_file"
        lines=$((lines + 1))
    done
}

fail() {
    log_error "$*"
    exit 1
}

check_ubuntu() {
    [[ -r /etc/os-release ]] || fail "No se pudo leer /etc/os-release"
    local id
    id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    [[ "$id" == "ubuntu" ]] || fail \
        "Este programa requiere Ubuntu; sistema detectado: ${id:-desconocido}"
}

avisar_actualizacion() {
    printf '\n  %bAviso:%b actualiza el sistema antes de continuar con Ubuntu Customizer.\n' \
        "$TN_YELLOW$BLD" "$RST"
    printf '  Ejecuta: %bsudo apt update && sudo apt upgrade%b\n\n' "$TN_CYAN" "$RST"
    printf '  %bPresiona una tecla para continuar...%b' "$TN_PURPLE" "$RST"
    read -rsn1 || true
    printf '\n'
}

run_python() {
    [[ -f "$PYTHON_INSTALLER" ]] || fail "No se encontró: $PYTHON_INSTALLER"

    local -a args=("$@")
    if [[ "$DRY_RUN" -eq 1 ]]; then
        args+=(--dry-run)
        log_info "Simulación: bash $PYTHON_INSTALLER ${args[*]}"
    fi

    bash "$PYTHON_INSTALLER" "${args[@]}"
}

PROGRESS_TASKS=(
    "Preparando entorno Python"
    "Dependencias del sistema"
    "Aplicaciones de desarrollo"
    "Zsh, Oh My Zsh y fuente Nerd"
    "Iconos Deepin SEA"
    "Extensiones de productividad"
    "Ubuntu Dock"
    "Wallpapers TokyoNight"
    "Tema TokyoNight"
    "Shell flotante y transparencia"
    "Perfil GNOME Terminal"
)
BRAILLE_SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPINNER_INDEX=0

render_progress() {
    local log_file="$1" finished="$2" exit_code="${3:-0}"
    refresh_terminal_size
    local current task marker color index last_lines
    current="$(grep '^@@PROGRESS START ' "$log_file" 2>/dev/null | tail -n1 | sed 's/^@@PROGRESS START //')"

    tput cup 0 0 2>/dev/null || printf '\033[H'
    printf '\033[J'
    draw_tokyo_frame "EJECUTANDO EN SEGUNDO PLANO" "WanTher  •  K3rNyx" "Ubuntu CLI"
    printf '\n'
    for index in "${!PROGRESS_TASKS[@]}"; do
        task="${PROGRESS_TASKS[$index]}"
        if grep -Fq "@@PROGRESS DONE $task" "$log_file" 2>/dev/null; then
            marker="${TN_GREEN}✓${RST}"
            color="$TN_GREEN"
        elif [[ "$task" == "$current" && "$finished" -eq 0 ]]; then
            marker="${TN_CYAN}${BRAILLE_SPINNER[$SPINNER_INDEX]}${RST}"
            color="$TN_CYAN"
        else
            marker="${DIM}·${RST}"
            color="$TN_FG"
        fi
        printf '  %b  %b%s%b\n' "$marker" "$color" "$task" "$RST"
    done
    printf '\n  %bÚltimas dos líneas del proceso%b\n' "$TN_PURPLE$BLD" "$RST"
    last_lines="$(grep -v '^@@PROGRESS ' "$log_file" 2>/dev/null | tail -n2 | sed -E 's/\x1B\[[0-9;?]*[ -/]*[@-~]//g')"
    if [[ -n "$last_lines" ]]; then
        while IFS= read -r line; do
            printf '    %s\n' "$line"
        done <<< "$last_lines"
    else
        printf '    %bEsperando salida...%b\n' "$DIM" "$RST"
    fi

    if [[ "$finished" -eq 1 ]]; then
        if [[ "$exit_code" -eq 0 ]]; then
            printf '\n  %b✓ Proceso completado%b\n' "$TN_GREEN$BLD" "$RST"
        else
            printf '\n  %b✗ Proceso falló (código %s)%b\n' "$TN_PINK$BLD" "$exit_code" "$RST"
        fi
    fi
    SPINNER_INDEX=$(( (SPINNER_INDEX + 1) % ${#BRAILLE_SPINNER[@]} ))
}

run_python_background() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        run_python "$@"
        return 0
    fi

    if [[ "$EUID" -ne 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            log_error "No se encontró sudo para instalar el perfil"
            return 1
        fi
        printf '\n  %bSe requieren permisos de administrador.%b\n' "$TN_YELLOW" "$RST"
        if ! sudo -v; then
            log_error "No se pudo validar la contraseña de sudo"
            return 1
        fi
    fi

    local log_file pid exit_code=0
    log_file="$(mktemp "${TMPDIR:-/tmp}/ubuntu-customizer-process.XXXXXX")"
    printf '%s\n' '@@PROGRESS START Preparando entorno Python' > "$log_file"
    bash "$PYTHON_INSTALLER" "$@" >>"$log_file" 2>&1 &
    pid=$!

    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        render_progress "$log_file" 0
        sleep 0.15
    done
    if wait "$pid"; then
        exit_code=0
    else
        exit_code=$?
    fi
    render_progress "$log_file" 1 "$exit_code"
    pause_screen
    rm -f -- "$log_file"
    tput rmcup 2>/dev/null || true
    tput cnorm 2>/dev/null || true
    return "$exit_code"
}

draw_menu() {
    refresh_terminal_size
    local redraw_static="${1:-0}"
    if [[ "$redraw_static" -eq 1 || ! -s "$BANNER_FILE" ]]; then
        local raw_banner
        raw_banner="$(mktemp)"
        show_banner > "$raw_banner"
        pad_banner_height "$raw_banner" "$BANNER_FILE"
        rm -f -- "$raw_banner"
        BANNER_LINES=$(wc -l < "$BANNER_FILE")
        clear
        cat "$BANNER_FILE"
        printf '  %bBanner %02d/%02d%b · %b%s%b\n' "$DIM$TN_PURPLE" \
            "${BANNER_LAST_INDEX:-0}" "${BANNER_TOTAL:-0}" "$RST" \
            "$DIM$TN_FG" "${BANNER_LAST_NAME:-desconocido}" "$RST"
        draw_tokyo_frame "UBUNTU CUSTOMIZER" "WanTher  •  K3rNyx" "Ubuntu CLI"
        printf '\n'
        MENU_START=$((BANNER_LINES + 7))
    fi

    tput cup "$MENU_START" 0 2>/dev/null || printf '\033[%dH' "$((MENU_START + 1))"
    printf '\033[J'

    local index marker color label plain padding description
    for index in "${!MENU_LABELS[@]}"; do
        marker="${TN_PURPLE}·${RST}"
        color="$TN_FG"
        if [[ "$index" -eq "$MENU_INDEX" ]]; then
            marker="${TN_CYAN}${BLD}❯${RST}"
            color="$TN_CYAN${BLD}"
        fi
        label="${MENU_LABELS[$index]}"
        plain="❯ [$((index + 1))] $label"
        printf '%*s%b  %b[%d] %s%b\n' "$MENU_PADDING" '' "$marker" "$color" \
            "$((index + 1))" "$label" "$RST"

        description="↳  ${MENU_DESCRIPTIONS[$index]}"
        printf '%*s%b%s%b\n' "$MENU_PADDING" '' "$DIM$TN_PURPLE" \
            "$description" "$RST"
    done

    plain='↑/↓ mover   Enter seleccionar   B cambiar banner   1-4 acceso rápido   Q salir'
    padding=$(( (TERM_W - ${#plain}) / 2 ))
    ((padding < 0)) && padding=0
    printf '\n%*s%b↑/↓%b mover   %bEnter%b seleccionar   %bB%b cambiar banner   %b1-4%b acceso rápido   %bQ%b salir\n' \
        "$padding" '' "$TN_CYAN" "$RST" "$TN_CYAN" "$RST" "$TN_CYAN" "$RST" \
        "$TN_CYAN" "$RST" "$TN_CYAN" "$RST"
}

pause_screen() {
    printf '\n  %bPresiona una tecla para continuar...%b' "$TN_PURPLE" "$RST"
    read -rsn1 || true
}

interactive_menu() {
    local key selected read_ok
    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    cleanup_menu() {
        rm -f -- "$BANNER_FILE"
        tput rmcup 2>/dev/null || true
        tput cnorm 2>/dev/null || true
    }
    trap cleanup_menu EXIT INT TERM
    trap 'draw_menu 1' WINCH

    draw_menu 1
    while true; do
        key=""
        if IFS= read -rsn3 -t 0.1 key; then
            read_ok=1
        else
            read_ok=0
        fi
        if [[ "$key" == $'\033[A' ]]; then
            MENU_INDEX=$(( (MENU_INDEX - 1 + ${#MENU_LABELS[@]}) % ${#MENU_LABELS[@]} ))
            draw_menu
        elif [[ "$key" == $'\033[B' ]]; then
            MENU_INDEX=$(( (MENU_INDEX + 1) % ${#MENU_LABELS[@]} ))
            draw_menu
        elif [[ "$key" == $'\033[H' ]]; then
            MENU_INDEX=0
            draw_menu
        elif [[ "$key" == $'\033[F' ]]; then
            MENU_INDEX=$((${#MENU_LABELS[@]} - 1))
            draw_menu
        elif [[ "$read_ok" -eq 1 && ( -z "$key" || "$key" == $'\n' || "$key" == $'\r' ) ]]; then
            selected="$MENU_INDEX"
            case "$selected" in
                0)
                    tput rmcup 2>/dev/null || true
                    tput cnorm 2>/dev/null || true
                    if ! run_python_background --tema tokyonight-storm --perfil wanther; then
                        :
                    fi
                    ;;
                1)
                    tput rmcup 2>/dev/null || true
                    tput cnorm 2>/dev/null || true
                    if ! run_python_background --tema tokyonight-storm --perfil k3rnyx; then
                        :
                    fi
                    ;;
                2)
                    tput rmcup 2>/dev/null || true
                    tput cnorm 2>/dev/null || true
                    if ! run_python --tema mostrar; then
                        :
                    fi
                    pause_screen
                    ;;
                3) return 0 ;;
            esac
            tput smcup 2>/dev/null || true
            tput civis 2>/dev/null || true
            draw_menu
        elif [[ "$key" =~ [1-4] ]]; then
            MENU_INDEX=$((key - 1))
            draw_menu
        elif [[ "$key" =~ [bB] ]]; then
            draw_menu 1
        elif [[ "$key" =~ [qQxX] ]]; then
            return 0
        fi
    done
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tema) ACTION=tema ;;
            --mostrar) ACTION=mostrar ;;
            --dry-run) DRY_RUN=1 ;;
            --perfil)
                [[ $# -ge 2 ]] || fail "--perfil requiere wanther o k3rnyx"
                PROFILE="$2"
                [[ "$PROFILE" == "wanther" || "$PROFILE" == "k3rnyx" ]] || \
                    fail "Perfil no reconocido: $PROFILE"
                shift
                ;;
            -h|--help)
                printf 'Uso: %s [--tema|--mostrar] [--perfil wanther|k3rnyx] [--dry-run]\n' "$0"
                exit 0
                ;;
            *) fail "Opción no reconocida: $1" ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    check_ubuntu
    avisar_actualizacion
    case "$ACTION" in
        tema) run_python --tema tokyonight-storm --perfil "$PROFILE" ;;
        mostrar) run_python --tema mostrar ;;
        menu) interactive_menu ;;
    esac
}

main "$@"
