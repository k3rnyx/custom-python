#!/bin/bash

run_figlet_banner() {
    local fonts=("slant" "big" "ansi-shadow")
    local idx=$((RANDOM % ${#fonts[@]}))
    local font="${fonts[$idx]}"
    if command -v figlet &>/dev/null; then
        local lines=() _first=1
        while IFS= read -r line; do
            ((_first)) && { _first=0; [[ -z "$line" ]] && continue; }
            lines+=("$line")
        done < <(figlet -f "$font" "K3RNYX" 2>/dev/null || figlet "K3RNYX" 2>/dev/null)
        ((${#lines[@]} == 0)) && return 1
        local colors=("$TN_CYAN" "$TN_BLUE" "$TN_PURPLE" "$TN_PINK")
local inner=$((TERM_W-2))
        printf -v bar '%*s' "$inner" ''; bar="${bar// /═}"
        echo
        echo -e "${TN_CYAN}╔${bar}╗${RST}"
        local ci=0 total=${#lines[@]}
        for line in "${lines[@]}"; do
            local len=${#line} lpad=0 rpad=0
            if ((len < inner)); then
                lpad=$(((inner - len) / 2))
                rpad=$((inner - len - lpad))
            fi
            printf -v lp '%*s' "$lpad" ''
            printf -v rp '%*s' "$rpad" ''
            local cidx=$((ci * ${#colors[@]} / total))
            ((cidx > 3)) && cidx=3
            echo -e "${TN_CYAN}║${RST}${lp}${colors[$cidx]}${line}${RST}${rp}${TN_CYAN}║${RST}"
            ci=$((ci + 1))
        done
        local sub="✦  K3RNYX  ✦"
        local slen=${#sub}
        local spad=$(((inner - slen) / 2))
        local rpad=$((inner - slen - spad))
        printf -v lp '%*s' "$spad" ''
        printf -v rp '%*s' "$rpad" ''
        echo -e "${TN_CYAN}║${RST}${lp}${TN_PURPLE}${BLD}${sub}${RST}${rp}${TN_CYAN}║${RST}"
        echo -e "${TN_CYAN}╚${bar}╝${RST}"
        echo
        return 0
    fi
    return 1
}

run_toilet_banner() {
    local fonts=("future" "metal" "mono9" "smblock")
    local idx=$((RANDOM % ${#fonts[@]}))
    local font="${fonts[$idx]}"
    if command -v toilet &>/dev/null; then
        local lines=() _first=1
        while IFS= read -r line; do
            ((_first)) && { _first=0; [[ -z "$line" ]] && continue; }
            lines+=("$line")
        done < <(toilet -w $((TERM_W-2)) -f "$font" "K3RNYX" 2>/dev/null)
        ((${#lines[@]} == 0)) && return 1
        local colors=("$TN_CYAN" "$TN_BLUE" "$TN_PURPLE" "$TN_PINK")
        local inner=$((TERM_W-2))
        printf -v bar '%*s' "$inner" ''; bar="${bar// /═}"
        echo
        echo -e "${TN_CYAN}╔${bar}╗${RST}"
        local ci=0 total=${#lines[@]}
        for line in "${lines[@]}"; do
            local len=${#line} lpad=0 rpad=0
            if ((len < inner)); then
                lpad=$(((inner - len) / 2))
                rpad=$((inner - len - lpad))
            fi
            printf -v lp '%*s' "$lpad" ''
            printf -v rp '%*s' "$rpad" ''
            local cidx=$((ci * ${#colors[@]} / total))
            ((cidx > 3)) && cidx=3
            echo -e "${TN_CYAN}║${RST}${lp}${colors[$cidx]}${line}${RST}${rp}${TN_CYAN}║${RST}"
            ci=$((ci + 1))
        done
        local sub="✦  K3RNYX  ✦"
        local slen=${#sub}
        local spad=$(((inner - slen) / 2))
        local rpad=$((inner - slen - spad))
        printf -v lp '%*s' "$spad" ''
        printf -v rp '%*s' "$rpad" ''
        echo -e "${TN_CYAN}║${RST}${lp}${TN_PURPLE}${BLD}${sub}${RST}${rp}${TN_CYAN}║${RST}"
        echo -e "${TN_CYAN}╚${bar}╝${RST}"
        echo
        return 0
    fi
    return 1
}

generate_banner_images() {
    if ! command -v python3 &>/dev/null; then
        echo "/tmp/tokyo-banners"
        return
    fi
    local tmp_dir="/tmp/tokyo-banners"
    mkdir -p "$tmp_dir"
    for theme in tower fuji torii lanterns abstract; do
        local file="${tmp_dir}/${theme}.png"
        [[ -f "$file" ]] && continue
        python3 -c "
from PIL import Image
w, h = 160, 45
pal = {'bg':(26,27,38),'cyan':(125,207,255),'blue':(122,162,247),'purple':(187,154,247),'pink':(247,118,142),'green':(158,206,106),'yellow':(224,175,104),'fg':(192,202,245),'white':(255,255,220)}
t = '$theme'
img = Image.new('RGB', (w, h))
px = img.load()
for y in range(h):
    for x in range(w):
        r, g, b = pal['bg']
        if t == 'tower':
            r = 26+int(y*10/h); g = 27+int(y*20/h); b = 38+int(y*15/h)
            if (x-130)**2+(y-12)**2<30: r,g,b = 255,255,210
            tx = abs(x-50); ty = y-5
            if ty>0 and tx<6-ty/8 and tx>0: r,g,b = pal['pink']
            if y>38: r,g,b = pal['purple']
        elif t == 'fuji':
            r = 20+int(y*8/h); g = 22+int(y*16/h); b = 30+int(y*12/h)
            dy = y-25; hw = 50-dy*2
            if dy>0 and abs(x-80)<hw:
                f = 1-dy/22; r=int(60+120*f); g=int(50+100*f); b=int(80+140*f)
            if dy>0 and dy<4 and abs(x-80)<hw*0.3: r,g,b = 255,255,250
            if 38<y<42 and int(abs(x/8))%3==0: r,g,b = pal['cyan']
            if (x-40)**2+(y-18)**2<40: r,g,b = pal['pink']
            if y>40: r,g,b = pal['bg']
        elif t == 'torii':
            r = 26+int(y*12/h); g = 27+int(y*20/h); b = 38+int(y*18/h)
            for px in [35,55,105,125]:
                if abs(x-px)<3 and 10<y<40: r,g,b = pal['pink']
            if 7<y<12 and 30<x<130:
                f = 1-abs(x-80)/55; r=int(pal['pink'][0]*f); g=int(pal['pink'][1]*f); b=int(pal['pink'][2]*f)
            if 15<y<18 and 32<x<128: r,g,b = pal['cyan']
            sd = (x-80)**2+(y-30)**2
            if sd<100:
                r2=int(pal['yellow'][0]*(1-sd/200)); g2=int(pal['yellow'][1]*(1-sd/200)); b2=int(pal['yellow'][2]*(1-sd/200))
                r=max(r,r2); g=max(g,g2); b=max(b,b2)
            if y>40: r,g,b = pal['green']; r=int(r*0.4); g=int(g*0.4); b=int(b*0.4)
        elif t == 'lanterns':
            r = 15+int(y*5/h); g = 16+int(y*8/h); b = 22+int(y*6/h)
            for lx,c in [(40,pal['pink']),(80,pal['purple']),(120,pal['cyan'])]:
                if abs(x-lx)<8 and 15<y<35:
                    f = 1-abs(y-25)/12; r=int(c[0]*f); g=int(c[1]*f); b=int(c[2]*f)
                    gd = (x-lx)**2+(y-25)**2
                    if gd<100: gl=1-gd/120; r=min(255,int(r+30*gl)); g=min(255,int(g+20*gl)); b=min(255,int(b+10*gl))
            if (x*7+y*13)%37==0 and y<12: r,g,b = 255,255,240
            if y>38: r=int(r*0.3); g=int(g*0.3); b=int(b*0.3)
        elif t == 'abstract':
            r = 20+int(y*8/h); g = 22+int(y*14/h); b = 30+int(y*10/h)
            for cx,cy,rad,col in [(40,20,18,pal['cyan']),(80,22,15,pal['purple']),(120,18,20,pal['pink'])]:
                d = (x-cx)**2+(y-cy)**2
                if d<rad**2: f=1-d/rad**2; r=int(col[0]*f); g=int(col[1]*f); b=int(col[2]*f)
                if (rad-2)**2<d<(rad-4)**2: r,g,b = 255,255,255
        px[x, y] = (r, g, b)
img.save('$file', 'PNG')
" 2>/dev/null || true
    done
    echo "$tmp_dir"
}

banner_chafa() {
    local tmp_dir
    tmp_dir=$(generate_banner_images)
    local themes=("tower" "fuji" "torii" "lanterns" "abstract")
    local idx=$((RANDOM % ${#themes[@]}))
    local img="${tmp_dir}/${themes[$idx]}.png"
    if [[ -f "$img" ]] && command -v chafa &>/dev/null; then
        local cols=$TERM_W
        chafa --color-space=rgb --symbols all --size="${cols}x25" "$img" 2>/dev/null || return 1
        echo
        draw_tokyo_frame "K3RNYX" "Tokyo Night Edition" "K3rNyx"
        return 0
    fi
    return 1
}

banner_jp2a() {
    if ! command -v jp2a &>/dev/null; then
        return 1
    fi
    local img=""
    [[ -f /usr/share/backgrounds/ubuntu-default-greyscale.png ]] && img="/usr/share/backgrounds/ubuntu-default-greyscale.png"
    [[ -z "$img" && -f /usr/share/backgrounds/warty-final-ubuntu.png ]] && img="/usr/share/backgrounds/warty-final-ubuntu.png"
    [[ -z "$img" && -f /usr/share/backgrounds/ubuntu-groovy-wallpaper.png ]] && img="/usr/share/backgrounds/ubuntu-groovy-wallpaper.png"
    [[ -z "$img" ]] && return 1
    local cols=$TERM_W
    jp2a --colors --width="$cols" "$img" 2>/dev/null || return 1
    echo
    draw_tokyo_frame "K3RNYX" "Tokyo Night Edition" "K3rNyx"
    return 0
}

# ── custom ASCII banners (no external tools) ────────────────
__bline() {
    local txt="$1" col="$2" i="$3"
    if [[ -z "$txt" ]]; then
        echo -e "${TN_CYAN}║${RST}  $(printf '%*s' "$i" '')  ${TN_CYAN}║${RST}"
    else
        local pl=$(((i - ${#txt}) / 2))
        local pr=$((i - pl - ${#txt}))
        echo -e "${TN_CYAN}║${RST}  $(printf '%*s' "$pl" '')${col}${txt}${RST}$(printf '%*s' "$pr" '')  ${TN_CYAN}║${RST}"
    fi
}

banner_custom_01() {
    local u="${USER:-?}" h=$(hostname 2>/dev/null || echo '?')
    local i=$((TERM_W-6))
    printf -v b '%*s' "$((TERM_W-2))" ''; b="${b// /═}"
    echo
    echo -e "${TN_CYAN}╔${b}╗${RST}"
    __bline "" "" "$i"
    __bline "▲  K3RNYX  ▲" "$TN_YELLOW" "$i"
    __bline "" "" "$i"
    __bline "◈  ${u}@${h}  ◈" "$TN_GREEN" "$i"
    __bline "" "" "$i"
    __bline "⚡  EDITION  ⚡" "$TN_PURPLE" "$i"
    __bline "" "" "$i"
    echo -e "${TN_CYAN}╚${b}╝${RST}"
    echo
}

banner_custom_02() {
    local u="${USER:-?}" h=$(hostname 2>/dev/null || echo '?')
    local i=$((TERM_W-6))
    printf -v b '%*s' "$((TERM_W-2))" ''; b="${b// /═}"
    echo
    echo -e "${TN_CYAN}╔${b}╗${RST}"
    __bline "" "" "$i"
    __bline "◆  K3RNYX  ◆" "$TN_BLUE" "$i"
    __bline "" "" "$i"
    __bline "•  ${u}@${h}  •" "$TN_CYAN" "$i"
    __bline "" "" "$i"
    __bline "◇  K3RNYX  ◇" "$TN_FG" "$i"
    __bline "" "" "$i"
    echo -e "${TN_CYAN}╚${b}╝${RST}"
    echo
}

banner_custom_03() {
    local u="${USER:-?}" h=$(hostname 2>/dev/null || echo '?')
    local i=$((TERM_W-6))
    printf -v b '%*s' "$((TERM_W-2))" ''; b="${b// /═}"
    echo
    echo -e "${TN_PURPLE}╔${b}╗${RST}"
    __bline "▲  K3RNYX  ▲" "$TN_YELLOW" "$i"
    __bline "◈  ${u}@${h}  ◈" "$TN_GREEN" "$i"
    __bline "⚡  EDITION  ⚡" "$TN_PURPLE" "$i"
    echo -e "${TN_PURPLE}╚${b}╝${RST}"
    echo
}

banner_custom_04() {
    local u="${USER:-?}" h=$(hostname 2>/dev/null || echo '?')
    local i=$((TERM_W-6))
    printf -v b '%*s' "$((TERM_W-2))" ''; b="${b// /═}"
    printf -v d '%*s' "$i" ''; d="${d// /─}"
    echo
    echo -e "${TN_CYAN}╔${b}╗${RST}"
    __bline "" "" "$i"
    __bline "★  K3RNYX  ★" "$TN_YELLOW" "$i"
    echo -e "${TN_CYAN}║${RST}  ${DIM}${d}${RST}  ${TN_CYAN}║${RST}"
    __bline "◎  ${u}@${h}  ◎" "$TN_PINK" "$i"
    echo -e "${TN_CYAN}║${RST}  ${DIM}${d}${RST}  ${TN_CYAN}║${RST}"
    __bline "★  K3RNYX  ★" "$TN_PURPLE" "$i"
    __bline "" "" "$i"
    echo -e "${TN_CYAN}╚${b}╝${RST}"
    echo
}

banner_custom_ascii() {
    local banners=(banner_custom_01 banner_custom_02 banner_custom_03 banner_custom_04 banner_custom_05 banner_custom_06)
    "${banners[$((RANDOM % ${#banners[@]}))]}"
}

banner_text_only() {
    draw_tokyo_frame "K3RNYX" "Tokyo Night Edition" "K3rNyx"
}

# ── Python-generated banners ─────────────────────────
banner_python_mandala() {
    command -v python3 &>/dev/null || return 1
    W=$TERM_W python3 << 'PYEOF'
import math, random, sys, os
random.seed()
W = int(os.environ.get('W', '72'))
H = max(14, W * 16 // 72)
cx, cy = W // 2, H // 2
n = random.choice([6, 8, 10])
pal = [(125,207,255), (122,162,247), (187,154,247), (247,118,142), (158,206,106), (224,175,104), (192,202,245)]
core = ['◇','●','⬢','★']
mid = ['◆','◈','▪','▫','✦','◎']
outer = ['·','░','▒','▓']
for y in range(H):
    line = []
    for x in range(W):
        dx, dy = x - cx, y - cy
        dist = math.sqrt(dx*dx + dy*dy)
        if dist < 0.5:
            line.append('\033[38;2;255;255;255m◇\033[0m')
        elif dist < 3.5:
            angle = math.atan2(dy, dx)
            sa = int((angle / (2*math.pi) + 0.5) * n) % n
            fade = max(0.6, 1 - dist * 0.1)
            ci = sa % 6
            r, g, b = pal[ci]
            r, g, b = int(r*fade), int(g*fade), int(b*fade)
            ch = core[(sa + int(dist*2)) % len(core)]
            line.append(f'\033[38;2;{r};{g};{b}m{ch}\033[0m')
        elif dist < 8.5:
            angle = math.atan2(dy, dx)
            sa = int((angle / (2*math.pi) + 0.5) * n) % n
            fade = max(0.3, 1 - dist * 0.06)
            ci = (sa + 3) % 6
            r, g, b = pal[ci]
            r, g, b = int(r*fade), int(g*fade), int(b*fade)
            ch = mid[(int(dist*1.5) + sa) % len(mid)]
            line.append(f'\033[38;2;{r};{g};{b}m{ch}\033[0m')
        elif dist < 11:
            angle = math.atan2(dy, dx)
            fade = max(0.15, 1 - dist * 0.05)
            ci = int((angle / (2*math.pi) + 1) * 3) % 6
            r, g, b = pal[ci]
            r, g, b = int(r*fade), int(g*fade), int(b*fade)
            ch = outer[int(dist * len(outer) / 11) % len(outer)]
            line.append(f'\033[38;2;{r};{g};{b}m{ch}\033[0m')
        else:
            line.append(' ')
    sys.stdout.write(''.join(line) + '\n')
print()
PYEOF
}

banner_python_skyline() {
    command -v python3 &>/dev/null || return 1
    W=$TERM_W python3 << 'PYEOF'
import math, random, sys, os
random.seed()
W = int(os.environ.get('W', '72'))
H = max(12, W * 14 // 72)
pal = {'bg':(26,27,38),'cyan':(125,207,255),'blue':(122,162,247),'purple':(187,154,247),'pink':(247,118,142),'yellow':(224,175,104),'fg':(192,202,245),'white':(255,255,220)}
blds = []
x = 1
while x < W - 1:
    w = random.randint(3, 9)
    h = random.randint(3, 10)
    if x + w > W - 1: w = W - 1 - x
    if w < 2: break
    ws = set()
    for _ in range(int(w * h * random.uniform(0.4, 0.7))):
        ws.add((random.randint(0, w-1), random.randint(0, h-1)))
    blds.append((x, w, h, ws))
    x += w + random.randint(1, 3)
stars = {}
for _ in range(45):
    sx, sy = random.randint(0, W-1), random.randint(0, H//2 + 1)
    bright = random.uniform(0.4, 1.0)
    col = random.choice([(255,255,255), pal['blue'], pal['cyan'], pal['fg']])
    col = (int(col[0]*bright), int(col[1]*bright), int(col[2]*bright))
    stars[(sx, sy)] = col
# moon
mx, my = random.randint(W-12, W-4), random.randint(1, 3)
moon_center = (mx, my)
moon_glow = 5
for y in range(H):
    line = []
    for x in range(W):
        if (x, y) in stars:
            r, g, b = stars[(x, y)]
            ch = random.choice(['·', '⋆', '·', '˚', '·', '✦'])
            line.append(f'\033[38;2;{r};{g};{b}m{ch}\033[0m')
        else:
            # moon glow
            md = math.sqrt((x-mx)**2 + (y-my)**2)
            if md < moon_glow:
                fade = max(0.1, 1 - md/moon_glow)
                r = int(255 * fade * 0.8)
                g = int(255 * fade * 0.7)
                b = int(200 * fade * 0.6)
                ch = '·' if md > 3 else ('◐' if md > 1.5 else '◉')
                line.append(f'\033[38;2;{r};{g};{b}m{ch}\033[0m')
            else:
                dr = False
                for bx, bw, bh, wss in blds:
                    if bx <= x < bx + bw and y >= H - bh:
                        wy = y - (H - bh)
                        if (x - bx, wy) in wss:
                            r, g, b = pal['yellow']
                            if random.random() < 0.25: r, g, b = pal['cyan']
                            if random.random() < 0.15: r, g, b = pal['pink']
                            line.append(f'\033[38;2;{r};{g};{b}m█\033[0m')
                        else:
                            fade = 1 - (wy / max(bh, 1)) * 0.6
                            r, g, b = pal['purple']
                            r, g, b = int(r*fade), int(g*fade), int(b*fade)
                            line.append(f'\033[38;2;{r};{g};{b}m█\033[0m')
                        dr = True; break
                if not dr:
                    # sky gradient
                    sky_fade = 1 - (y / H) * 0.6
                    if y < 3:
                        r, g, b = pal['blue']
                        r, g, b = int(r*sky_fade*0.3), int(g*sky_fade*0.3), int(b*sky_fade*0.4)
                        line.append(f'\033[38;2;{r};{g};{b}m▓\033[0m')
                    elif y < 5:
                        r, g, b = pal['purple']
                        r, g, b = int(r*sky_fade*0.15), int(g*sky_fade*0.15), int(b*sky_fade*0.2)
                        line.append(f'\033[38;2;{r};{g};{b}m▒\033[0m')
                    else:
                        line.append(' ')
    sys.stdout.write(''.join(line) + '\n')
print()
PYEOF
}

banner_python_wave() {
    command -v python3 &>/dev/null || return 1
    W=$TERM_W python3 << 'PYEOF'
import math, random, sys, os
random.seed()
W = int(os.environ.get('W', '72'))
H = max(10, W * 12 // 72)
pal = [(125,207,255), (122,162,247), (187,154,247), (247,118,142), (158,206,106), (224,175,104)]
random.shuffle(pal)
c1, c2, c3 = pal[0], pal[1], pal[2]
blocks = ['█','▓','▒','░','▆','▅','▄','▃','▂','▁']
for y in range(H):
    line = []
    for x in range(W):
        v1 = math.sin(x * 0.15 + y * 0.4) * 0.5
        v2 = math.sin(x * 0.3 + y * 0.25 + 1.2) * 0.3
        v3 = math.sin(x * 0.07 + y * 0.6 + 2.8) * 0.2
        v4 = math.sin(x * 0.5 + y * 0.15 + 0.7) * 0.15
        v = (v1 + v2 + v3 + v4) * 0.43 + 0.5
        v = max(0.0, min(1.0, v))
        layer = y / H
        if layer < 0.33:
            r = int(c1[0] * (1-v) + c2[0] * v)
            g = int(c1[1] * (1-v) + c2[1] * v)
            b = int(c1[2] * (1-v) + c2[2] * v)
        elif layer < 0.66:
            r = int(c2[0] * (1-v) + c3[0] * v)
            g = int(c2[1] * (1-v) + c3[1] * v)
            b = int(c2[2] * (1-v) + c3[2] * v)
        else:
            r = int(c3[0] * (1-v) + pal[3][0] * v)
            g = int(c3[1] * (1-v) + pal[3][1] * v)
            b = int(c3[2] * (1-v) + pal[3][2] * v)
        bi = min(int(v * len(blocks)), len(blocks)-1)
        ch = ' ' if v < 0.25 else blocks[bi]
        line.append(f'\033[38;2;{r};{g};{b}m{ch}\033[0m')
    sys.stdout.write(''.join(line) + '\n')
print()
PYEOF
}

# ── Tool-based banners ───────────────────────────────
banner_fastfetch() {
    command -v fastfetch &>/dev/null || return 1
    local i=$((TERM_W-6))
    printf -v b '%*s' "$((TERM_W-2))" ''; b="${b// /═}"
    local raw=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        raw+=("$line")
    done < <(fastfetch --logo none 2>/dev/null | sed '/^\s*$/d')
    ((${#raw[@]} < 3)) && return 1

    local _zoff=0
    [[ -z "${raw[0]:-}" && -n "${raw[1]:-}" ]] && _zoff=1
    local host_line="${raw[$_zoff]}"
    local labels=() values=()
    for line in "${raw[@]}"; do
        [[ "$line" == *"---"* ]] && continue
        if [[ "$line" == *": "* ]]; then
            local label="${line%%:*}"
            local value="${line#*: }"
            [[ "$label" == Host || "$label" == Display* || "$label" == "WM Theme" ]] && continue
            labels+=("$label")
            values+=("$value")
            ((${#labels[@]} >= 6)) && break
        fi
    done
    ((${#labels[@]} < 1)) && return 1

    local prefixes=("◈" "◆" "◈" "◆" "◈" "◆")
    local pcols=("$TN_CYAN" "$TN_BLUE" "$TN_PURPLE" "$TN_PINK" "$TN_GREEN" "$TN_YELLOW")

    echo
    echo -e "${TN_CYAN}╔${b}╗${RST}"
    __bline "" "" "$i"

    local hdr="⚡  K3RNYX  ⚡"
    local hlen=${#hdr}
    local hpad=$(((i - hlen) / 2))
    printf -v hp '%*s' "$hpad" ''
    printf -v hs '%*s' "$((i - hpad - hlen))" ''
    echo -e "${TN_CYAN}║${RST}  ${hp}${TN_YELLOW}${hdr}${RST}${hs}  ${TN_CYAN}║${RST}"

    printf -v sep '%*s' "$((i - 2))" ''; sep="${sep// /─}"
    echo -e "${TN_CYAN}║${RST}  ${DIM}${TN_PURPLE}${sep}${RST}  ${TN_CYAN}║${RST}"

    local hl=$(echo "$host_line" | awk '{$1=$1};1')
    local hhlen=${#hl}
    local hhpad=$(((i - hhlen) / 2))
    printf -v hhp '%*s' "$hhpad" ''
    printf -v hhs '%*s' "$((i - hhpad - hhlen))" ''
    echo -e "${TN_CYAN}║${RST}  ${hhp}${TN_FG}${hl}${RST}${hhs}  ${TN_CYAN}║${RST}"

    __bline "" "" "$i"

    [[ -z "${values[0]:-}" && -n "${values[1]:-}" ]] && _zoff=1
    for ((idx=_zoff; idx<${#labels[@]}+_zoff; idx++)); do
        local label="${labels[$idx]}"
        local value="${values[$idx]}"
        local prefix="${prefixes[$idx]}"
        local col="${pcols[$idx]}"
        local max_val=$((i - 13))
        if ((${#value} > max_val)); then
            value="${value:0:$max_val}…"
        fi
        local rpad=$((i - 13 - ${#value}))
        printf -v rp '%*s' "$rpad" ''
        echo -e "${TN_CYAN}║${RST}  ${col}${prefix}${RST} ${BLD}${col}$(printf '%-10s' "$label")${RST} ${TN_FG}${value}${RST}${rp}  ${TN_CYAN}║${RST}"
    done

    __bline "" "" "$i"
    echo -e "${TN_CYAN}╚${b}╝${RST}"
    echo
}

# ── Custom ASCII banners ─────────────────────────────
banner_custom_05() {
    local u="${USER:-?}" h=$(hostname 2>/dev/null || echo '?')
    local i=$((TERM_W-6))
    printf -v b '%*s' "$((TERM_W-2))" ''; b="${b// /═}"
    echo
    echo -e "${TN_PINK}╔${b}╗${RST}"
    __bline "" "" "$i"
    __bline "◆  K3RNYX  ◆" "$TN_YELLOW" "$i"
    __bline "⬢  ${u}@${h}  ⬢" "$TN_CYAN" "$i"
    __bline "" "" "$i"
    printf -v sep '%*s' "$i" ''; sep="${sep// /─}"
    echo -e "${TN_CYAN}║${RST}  ${DIM}${sep}${RST}  ${TN_CYAN}║${RST}"
    __bline "◉  EDITION  ◉" "$TN_PURPLE" "$i"
    __bline "" "" "$i"
    echo -e "${TN_PINK}╚${b}╝${RST}"
    echo
}

banner_custom_06() {
    local u="${USER:-?}" h=$(hostname 2>/dev/null || echo '?')
    local d=$(date '+%Y-%m-%d')
    local i=$((TERM_W-6))
    printf -v b '%*s' "$((TERM_W-2))" ''; b="${b// /═}"
    printf -v s '%*s' "$i" ''; s="${s// /═}"
    echo
    echo -e "${TN_BLUE}╔${b}╗${RST}"
    __bline "" "" "$i"
    __bline "★  K3RNYX  ★" "$TN_YELLOW" "$i"
    __bline "" "" "$i"
    __bline "◎  ${u}@${h}  ◎" "$TN_CYAN" "$i"
    __bline "" "" "$i"
    echo -e "${TN_BLUE}║${RST}  ${DIM}${s}${RST}  ${TN_BLUE}║${RST}"
    __bline "" "" "$i"
    __bline "✦  K3RNYX  ✦" "$TN_GREEN" "$i"
    __bline "" "" "$i"
    echo -e "${TN_BLUE}╚${b}╝${RST}"
    echo
}

show_banner() {
    local available=()

    command -v figlet &>/dev/null && available+=(run_figlet_banner)
    command -v toilet &>/dev/null && available+=(run_toilet_banner)
    command -v python3 &>/dev/null && available+=(banner_python_skyline banner_python_wave)
    command -v fastfetch &>/dev/null && available+=(banner_fastfetch)
    available+=(banner_custom_ascii banner_custom_05 banner_custom_06)

    local idx=$((RANDOM % ${#available[@]}))
    BANNER_LAST_INDEX=$((idx + 1))
    BANNER_TOTAL=${#available[@]}
    BANNER_LAST_NAME="${available[$idx]}"
    if ! "${available[$idx]}"; then
        BANNER_LAST_NAME="banner_text_only (fallback)"
        banner_text_only
    fi
}
