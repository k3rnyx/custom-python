#!/bin/bash

# Exported as part of the public color palette for scripts that source ui.sh.
# shellcheck disable=SC2034
readonly TN_BG='\e[48;2;26;27;38m'
readonly TN_FG='\e[38;2;192;202;245m'
readonly TN_CYAN='\e[38;2;125;207;255m'
readonly TN_BLUE='\e[38;2;122;162;247m'
readonly TN_PURPLE='\e[38;2;187;154;247m'
readonly TN_PINK='\e[38;2;247;118;142m'
readonly TN_GREEN='\e[38;2;158;206;106m'
readonly TN_YELLOW='\e[38;2;224;175;104m'
readonly RST='\e[0m'
readonly BLD='\e[1m'
readonly DIM='\e[2m'

terminal_width() {
    local width
    width=$(tput cols 2>/dev/null || printf '80')
    [[ "$width" =~ ^[0-9]+$ ]] || width=80
    ((width < 40)) && width=40
    printf '%s' "$width"
}

refresh_terminal_size() {
    TERM_W=$(terminal_width)
}

refresh_terminal_size

log_info()    { echo -e "  ${TN_CYAN}◆${RST}  ${TN_FG}$*${RST}"; }
log_ok()      { echo -e "  ${TN_GREEN}✓${RST}  ${TN_FG}$*${RST}"; }
log_error()   { echo -e "  ${TN_PINK}✗${RST}  ${TN_FG}$*${RST}"; }
log_warn()    { echo -e "  ${TN_YELLOW}⚠${RST}  ${TN_FG}$*${RST}"; }
log_skip()    { echo -e "  ${TN_BLUE}⏭${RST}  ${TN_FG}$*${RST}"; }
log_detail()  { echo -e "     ${TN_PURPLE}↳${RST}  ${DIM}$*${RST}"; }

run_with_spinner() {
    local msg="$1"; shift
    local pid rc
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    echo -ne "     ${TN_CYAN}${spin[0]}${RST}  ${TN_FG}${msg}...${RST}"
    "$@" &>/dev/null &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "\r\e[2K     ${TN_CYAN}${spin[$i]}${RST}  ${TN_FG}${msg}...${RST}"
        i=$(( (i + 1) % ${#spin[@]} ))
        sleep 0.1
    done
    if wait "$pid"; then
        rc=0
    else
        rc=$?
    fi
    if ((rc == 0)); then
        printf '\r\033[2K     %b✓%b  %b%s%b\n' "$TN_GREEN" "$RST" "$TN_FG" "$msg" "$RST"
    else
        printf '\r\033[2K     %b✗%b  %b%s (código %d)%b\n' \
            "$TN_PINK" "$RST" "$TN_FG" "$msg" "$rc" "$RST"
    fi
    return $rc
}

draw_progress_bar() {
    local current=$1 total=$2 width=$((TERM_W / 5))
    ((total < 1)) && total=1
    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    printf -v bar '%*s' "$filled" ''; bar=${bar// /■}
    printf -v rest '%*s' "$empty" ''; rest=${rest// /□}
    echo -ne "  ${TN_CYAN}${bar}${TN_FG}${rest}${RST}  ${TN_PURPLE}${pct}%${RST}  ${TN_FG}(${current}/${total})${RST}"
}

draw_tokyo_frame() {
    local title="$1" subtitle="$2" credit="$3"
    local mw=$((TERM_W > 80 ? 80 : TERM_W))
    local lo=$(((TERM_W - mw) / 2))
    ((lo < 0)) && lo=0
    printf -v lf '%*s' "$lo" ''
    local inner=$((mw - 2))
    printf -v line '%*s' "$inner" ''; line=${line// /═}
    local tlen=${#title} slen=${#subtitle}
    local pad=$((inner - tlen - slen - 2))
    ((pad < 1)) && pad=1
    printf -v spaces '%*s' "$pad" ''
    local pr="${lf}${TN_CYAN}"
    echo -e "${pr}╔${line}╗${RST}"
    echo -e "${pr}║${RST} ${TN_PURPLE}${BLD}${title}${RST}${TN_FG}${spaces}${subtitle} ${TN_CYAN}║${RST}"
    if [[ -n "$credit" ]]; then
        printf -v sp '%*s' "$inner" ''
        echo -e "${pr}║${RST}${TN_FG}${sp}${TN_CYAN}║${RST}"
        local txt="by ${credit}"
        local tpad=$((inner - ${#txt} - 2))
        ((tpad < 1)) && tpad=1
        printf -v sp '%*s' "$tpad" ''
        echo -e "${pr}║${RST} ${TN_FG}${sp}${TN_PURPLE}${txt}${RST} ${TN_CYAN}║${RST}"
    fi
    echo -e "${pr}╚${line}╝${RST}"
}

log_section() {
    local title="$1" icon="$2"
    local w
    w=$(tput cols 2>/dev/null || echo 60)
    ((w = w > TERM_W ? TERM_W : w))
    ((w = w < 40 ? 40 : w))
    local inner=$((w - 2))
    printf -v line '%*s' "$inner" ''; line=${line// /═}
    local tlen=${#title}
    local pad_len=$((inner - tlen - 5))
    ((pad_len < 1)) && pad_len=1
    printf -v pad '%*s' "$pad_len" ''
    echo -e "${TN_CYAN}╔${line}╗${RST}"
    echo -e "${TN_CYAN}║${RST}   ${TN_PURPLE}${icon}${BLD} ${title}${RST}${TN_FG}${pad}${TN_CYAN}║${RST}"
    echo -e "${TN_CYAN}╚${line}╝${RST}"
    echo
}

prompt_input() {
    local label="$1" default="$2"
    echo -ne "  ${TN_PURPLE}?${RST}  ${TN_FG}${label} ${TN_CYAN}[${default}]${RST} " >/dev/tty
    read -r val || true
    echo "${val:-$default}"
}
