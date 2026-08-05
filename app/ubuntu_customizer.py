"""Personalizador de Ubuntu en un único archivo ejecutable."""

from __future__ import annotations

import argparse
import contextlib
import curses
import io
import os
import json
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from collections import deque
from collections.abc import Callable
from pathlib import Path
from urllib.parse import urljoin
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen, urlretrieve

try:
    from InquirerPy import inquirer
except ImportError:
    inquirer = None

REPOSITORIO_TOKYONIGHT = "https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme.git"
CARPETA_INSTALACION = ".cache/ubuntu-customizer/Tokyonight-GTK-Theme"
OH_MY_ZSH_REPO = "https://github.com/ohmyzsh/ohmyzsh.git"
ZSH_PLUGIN_REPOS = {
    "zsh-autosuggestions": "https://github.com/zsh-users/zsh-autosuggestions.git",
    "zsh-syntax-highlighting": "https://github.com/zsh-users/zsh-syntax-highlighting.git",
    "zsh-completions": "https://github.com/zsh-users/zsh-completions.git",
}
NERD_FONT_URL = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
OH_MY_ZSH_DIR = Path.home() / ".oh-my-zsh"
ZSH_CUSTOM_DIR = OH_MY_ZSH_DIR / "custom"
FONT_DIR = Path.home() / ".local/share/fonts/JetBrainsMono Nerd Font"
ZSH_MARKER_START = "# >>> ubuntu-customizer: zsh >>>"
ZSH_MARKER_END = "# <<< ubuntu-customizer: zsh <<<"
PROMPT_MARKER_START = "# >>> ubuntu-customizer: prompt >>>"
PROMPT_MARKER_END = "# <<< ubuntu-customizer: prompt <<<"

Progreso = Callable[[str, bool], None]
Accion = Callable[[Progreso, str | None], None]


def ejecutar_comando(
    comando: list[str],
    *,
    dry_run: bool = False,
    sudo_password: str | None = None,
) -> None:
    """Muestra y ejecuta un comando, o solo lo muestra en simulación."""
    print(f"\n$ {' '.join(comando)}")
    if not dry_run:
        es_apt = "apt-get" in comando
        if comando and comando[0] == "sudo" and sudo_password is not None:
            prefijo = ["sudo", "-S"]
            if es_apt:
                prefijo += ["env", "DEBIAN_FRONTEND=noninteractive"]
            comando = [*prefijo, *comando[1:]]
            opciones = {"input": f"{sudo_password}\n"}
        else:
            if es_apt and comando and comando[0] == "sudo":
                comando = ["sudo", "env", "DEBIAN_FRONTEND=noninteractive", *comando[1:]]
            opciones = {}
        try:
            resultado = subprocess.run(
                comando,
                text=True,
                check=True,
                **opciones,
            )
        except subprocess.CalledProcessError as error:
            raise


def comprobar_ubuntu() -> None:
    """Comprueba que el sistema actual sea Ubuntu."""
    datos: dict[str, str] = {}
    try:
        lineas = Path("/etc/os-release").read_text(encoding="utf-8").splitlines()
        for linea in lineas:
            if "=" in linea:
                clave, valor = linea.split("=", 1)
                datos[clave] = valor.strip('"')
    except OSError as error:
        raise RuntimeError("No se pudo leer /etc/os-release") from error

    if datos.get("ID") != "ubuntu":
        raise RuntimeError(
            f"Este script está pensado para Ubuntu; sistema detectado: {datos.get('NAME', 'desconocido')}"
        )


def comprobar_comando(nombre: str) -> None:
    if shutil.which(nombre) is None:
        raise RuntimeError(f"No se encontró el comando requerido: {nombre}")


EQUIVALENTES_PAQUETES = {
    "docker-compose-v2": ("docker-compose-plugin",),
}


def _paquete_instalado(nombre: str) -> bool:
    resultado = subprocess.run(
        ["dpkg-query", "-W", "-f=${Status}", nombre],
        capture_output=True,
        text=True,
    )
    return resultado.returncode == 0 and resultado.stdout.strip() == "install ok installed"


def _dependencias_faltantes(dependencias: list[str]) -> list[str]:
    """Devuelve solo paquetes ausentes, respetando paquetes equivalentes."""
    faltantes = []
    for paquete in dependencias:
        if _paquete_instalado(paquete):
            continue
        equivalentes = EQUIVALENTES_PAQUETES.get(paquete, ())
        if any(_paquete_instalado(alternativa) for alternativa in equivalentes):
            print(f"Dependencia cubierta: {paquete} ← {', '.join(equivalentes)}")
            continue
        faltantes.append(paquete)
    return faltantes


def error_fatal(error: Exception) -> int:
    print(f"\nError: {error}", file=sys.stderr)
    return 1


def progreso_cli(tarea: str, terminada: bool = False) -> None:
    """Emite eventos compactos para el monitor de progreso del lanzador Bash."""
    estado = "DONE" if terminada else "START"
    print(f"@@PROGRESS {estado} {tarea}", flush=True)
OPCIONES = (
    ("Personalización completa", "Tema, shell, iconos, extensiones y Ubuntu Dock"),
    ("Ver configuración actual", "Revisa el estado visual de tu escritorio"),
    ("Salir", "Cerrar Ubuntu Customizer"),
)
BANNER = (
    " _  ______    _  _          ",
    "| |/ /__ /_ _| \\| |_  ___ __",
    "| ' < |_ \\ '_| .` | || \\ \\/ /",
    "|_|\\_\\___/_| |_\\_|\\_, /_\\_\\",
    "                   |__/     ",
)
ANSI_BANNER = ("\033[38;2;125;207;255m", "\033[38;2;122;162;247m", "\033[38;2;187;154;247m")
ANSI_RESET = "\033[0m"
MASCARA_CONTRASENA = "⣿"  # U+28FF, BRAILLE PATTERN DOTS-12345678


def _texto(stdscr: curses.window, y: int, x: int, contenido: str, ancho: int, estilo: int = 0) -> None:
    """Escribe una línea recortada para evitar errores en terminales pequeñas."""
    if y < 0 or y >= stdscr.getmaxyx()[0] or ancho <= 0:
        return
    try:
        stdscr.addstr(y, x, contenido[:ancho], estilo)
    except curses.error:
        pass


def _colores() -> dict[str, int]:
    if not curses.has_colors():
        return {"normal": curses.A_NORMAL, "title": curses.A_BOLD, "active": curses.A_REVERSE, "dim": curses.A_DIM, "frame": curses.A_BOLD}
    curses.start_color()
    curses.use_default_colors()
    curses.init_pair(1, curses.COLOR_CYAN, -1)
    curses.init_pair(2, curses.COLOR_GREEN, -1)
    curses.init_pair(3, curses.COLOR_YELLOW, -1)
    curses.init_pair(4, curses.COLOR_MAGENTA, -1)
    return {
        "normal": curses.color_pair(1),
        "title": curses.color_pair(1) | curses.A_BOLD,
        "active": curses.color_pair(2) | curses.A_BOLD,
        "dim": curses.color_pair(4) | curses.A_DIM,
        "frame": curses.color_pair(1) | curses.A_BOLD,
    }


def _dibujar(stdscr: curses.window, seleccionado: int) -> None:
    stdscr.clear()
    alto, ancho_terminal = stdscr.getmaxyx()
    colores = _colores()
    ancho = min(76, ancho_terminal - 2)
    if ancho < 42:
        _texto(stdscr, max(0, alto // 2), 1, "Amplía la terminal para usar el menú.", max(1, ancho_terminal - 2), curses.A_BOLD)
        stdscr.refresh()
        return
    izquierda = max(0, (ancho_terminal - ancho) // 2)
    interior = ancho - 2
    marco = "═" * interior
    alto_menu = 21
    base = max(0, (alto - alto_menu) // 2)
    fin = base + 20 if alto >= alto_menu else min(max(0, alto - 1), base + 7)

    def linea(y: int, contenido: str = "", estilo: int = 0) -> None:
        _texto(stdscr, y, izquierda, "║", 1, colores["frame"])
        _texto(stdscr, y, izquierda + 1, contenido[:interior].ljust(interior), interior, estilo)
        _texto(stdscr, y, izquierda + ancho - 1, "║", 1, colores["frame"])

    def linea_mixta(y: int, partes: tuple[tuple[str, int], ...]) -> None:
        """Dibuja una línea con colores distintos sin romper el marco."""
        _texto(stdscr, y, izquierda, "║", 1, colores["frame"])
        cursor = izquierda + 1
        usados = 0
        for texto, estilo in partes:
            visible = texto[: max(0, interior - usados)]
            _texto(stdscr, y, cursor, visible, len(visible), estilo)
            cursor += len(visible)
            usados += len(visible)
        if usados < interior:
            _texto(stdscr, y, cursor, " " * (interior - usados), interior - usados, colores["normal"])
        _texto(stdscr, y, izquierda + ancho - 1, "║", 1, colores["frame"])

    if alto < alto_menu or ancho_terminal < 42:
        _texto(stdscr, base, izquierda, "╔" + marco + "╗", ancho, colores["frame"])
        linea(base + 1, "UBUNTU CUSTOMIZER".center(interior), colores["title"])
        _texto(stdscr, base + 2, izquierda, "╠" + marco + "╣", ancho, colores["frame"])
        linea(base + 4, "Terminal demasiado pequeña".center(interior), curses.A_BOLD)
        linea(base + 5, "Amplíala para usar el menú.".center(interior), colores["dim"])
    else:
        _texto(stdscr, base, izquierda, "╔" + marco + "╗", ancho, colores["frame"])
        for indice, banner_linea in enumerate(BANNER):
            linea(
                base + 1 + indice,
                banner_linea.center(interior),
                colores["title"] if indice % 2 == 0 else colores["normal"],
            )
        linea(base + 7, "Personaliza tu escritorio GNOME".center(interior), colores["dim"])
        _texto(stdscr, base + 8, izquierda, "╠" + marco + "╣", ancho, colores["frame"])
        linea(base + 9, "Selecciona una acción:".center(interior), colores["normal"])
        linea(base + 10)
        for indice, (nombre, descripcion) in enumerate(OPCIONES):
            y = base + 11 + indice
            activo = indice == seleccionado
            puntero = "❯" if activo else " "
            estilo = colores["active"] if activo else colores["normal"]
            sangria = " " * 10
            linea(y, f"{sangria}{puntero} [{indice + 1}] {nombre}".ljust(interior), estilo)
        linea(base + 14)
        linea(base + 15, "Detalle de la selección".center(interior), colores["normal"])
        linea(base + 16, OPCIONES[seleccionado][1].center(interior), colores["dim"])
        linea(base + 17)
        linea(
            base + 18,
            "↑/↓ mover   Enter seleccionar   1-3 acceso rápido   q salir".center(interior),
            colores["dim"],
        )
        linea(base + 19)

    _texto(stdscr, fin, izquierda, "╚" + marco + "╝", ancho, colores["frame"])
    stdscr.refresh()


def _seleccionar(stdscr: curses.window) -> int | None:
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    stdscr.keypad(True)
    seleccionado = 0
    while True:
        _dibujar(stdscr, seleccionado)
        tecla = stdscr.getch()
        if tecla in (curses.KEY_UP, ord("k")):
            seleccionado = (seleccionado - 1) % len(OPCIONES)
        elif tecla in (curses.KEY_DOWN, ord("j")):
            seleccionado = (seleccionado + 1) % len(OPCIONES)
        elif tecla in (curses.KEY_ENTER, 10, 13):
            return seleccionado
        elif tecla in (ord("1"), ord("2"), ord("3")):
            return tecla - ord("1")
        elif tecla in (ord("q"), ord("Q"), 27):
            return 2


def _seleccionar_inquirer() -> int | None:
    if inquirer is None:
        return None
    _imprimir_banner()
    try:
        respuesta = inquirer.select(
            message="¿Qué deseas hacer?",
            choices=[
                "Personalización completa",
                "Ver configuración actual",
                "Salir",
            ],
            pointer="❯",
            qmark="◆",
            instruction="Usa ↑/↓ y Enter · q para salir",
        ).execute()
    except (KeyboardInterrupt, EOFError):
        return 2
    return {
        "Personalización completa": 0,
        "Ver configuración actual": 1,
        "Salir": 2,
    }.get(respuesta)


def _imprimir_banner() -> None:
    """Muestra el banner solicitado con degradado Tokyo Night."""
    for indice, linea in enumerate(BANNER):
        if sys.stdout.isatty():
            color = ANSI_BANNER[indice % len(ANSI_BANNER)]
            print(f"{color}{linea}{ANSI_RESET}")
        else:
            print(linea)
    print("  Personaliza tu escritorio GNOME")


class _EstadoProceso:
    """Estado compartido entre el worker y la pantalla curses."""

    def __init__(self) -> None:
        self.bloqueo = threading.Lock()
        self.actual = "Preparando proceso"
        self.completadas: set[str] = set()
        self.salida: deque[str] = deque(maxlen=2)
        self.error: str | None = None
        self.terminado = False
        self.password: str | None = None

    def progreso(self, tarea: str, terminada: bool = False) -> None:
        with self.bloqueo:
            if terminada:
                self.completadas.add(tarea)
            else:
                self.actual = tarea

    def linea(self, texto: str) -> None:
        with self.bloqueo:
            for linea in texto.splitlines():
                if linea.strip():
                    self.salida.append(linea.strip())


class _SalidaProceso(io.TextIOBase):
    def __init__(self, estado: _EstadoProceso) -> None:
        self.estado = estado

    def write(self, texto: str) -> int:
        self.estado.linea(texto)
        return len(texto)

    def flush(self) -> None:
        return None


def _dibujar_proceso(stdscr: curses.window, estado: _EstadoProceso, frame: int) -> None:
    stdscr.clear()
    alto, ancho_terminal = stdscr.getmaxyx()
    colores = _colores()
    ancho = min(76, ancho_terminal - 2)
    if ancho < 48:
        _texto(stdscr, max(0, alto // 2), 1, "Amplía la terminal para ver el progreso.", max(1, ancho_terminal - 2), curses.A_BOLD)
        stdscr.refresh()
        return
    izquierda = max(0, (ancho_terminal - ancho) // 2)
    interior = ancho - 2
    marco = "═" * interior
    spinner = ("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
    spinner_estilos = (
        colores["normal"],
        colores["title"],
        colores["active"],
        colores["dim"],
    )
    tareas = (
        "Dependencias del sistema",
        "Zsh, Oh My Zsh y fuente Nerd",
        "Iconos Deepin SEA",
        "Extensiones de productividad",
        "Ubuntu Dock",
        "Tema TokyoNight",
        "Shell flotante y transparencia",
        "Perfil GNOME Terminal",
    )
    alto_contenido = 22
    base = max(0, (alto - alto_contenido) // 2)

    def linea(y: int, contenido: str = "", estilo: int = 0) -> None:
        _texto(stdscr, y, izquierda, "║", 1, colores["frame"])
        _texto(stdscr, y, izquierda + 1, contenido[:interior].ljust(interior), interior, estilo)
        _texto(stdscr, y, izquierda + ancho - 1, "║", 1, colores["frame"])

    def linea_mixta(y: int, partes: tuple[tuple[str, int], ...]) -> None:
        """Dibuja el spinner con su color independiente del texto."""
        _texto(stdscr, y, izquierda, "║", 1, colores["frame"])
        cursor = izquierda + 1
        usados = 0
        for texto, estilo in partes:
            visible = texto[: max(0, interior - usados)]
            _texto(stdscr, y, cursor, visible, len(visible), estilo)
            cursor += len(visible)
            usados += len(visible)
        if usados < interior:
            _texto(stdscr, y, cursor, " " * (interior - usados), interior - usados, colores["normal"])
        _texto(stdscr, y, izquierda + ancho - 1, "║", 1, colores["frame"])

    _texto(stdscr, base, izquierda, "╔" + marco + "╗", ancho, colores["frame"])
    linea(base + 1, " PERSONALIZANDO EL ESCRITORIO ".center(interior), colores["title"])
    linea(base + 2, "El proceso continúa en segundo plano".center(interior), colores["dim"])
    _texto(stdscr, base + 3, izquierda, "╠" + marco + "╣", ancho, colores["frame"])
    linea(base + 4)
    with estado.bloqueo:
        completadas = set(estado.completadas)
        actual = estado.actual
        salida = list(estado.salida)
        error = estado.error
        terminado = estado.terminado
    for indice, tarea in enumerate(tareas):
        y = base + 5 + indice
        if tarea in completadas:
            linea_mixta(y, ((" ✓", colores["active"]), (f" {tarea}", colores["normal"])))
            continue
        elif tarea == actual and not terminado:
            marca = spinner[frame % len(spinner)]
            linea_mixta(
                y,
                (
                    (f" {marca}", spinner_estilos[frame % len(spinner_estilos)]),
                    (f" {tarea}", colores["normal"]),
                ),
            )
            continue
        else:
            linea_mixta(y, ((" ·", colores["dim"]), (f" {tarea}", colores["normal"])))
    fin_tareas = base + 5 + len(tareas)
    linea(fin_tareas)
    _texto(stdscr, fin_tareas + 1, izquierda, "╠" + marco + "╣", ancho, colores["frame"])
    if error:
        linea(fin_tareas + 2, f"✗ Error: {error}", curses.A_BOLD)
    elif terminado:
        linea(fin_tareas + 2, "✓ Proceso finalizado · pulsa una tecla para continuar", colores["active"])
    else:
        linea_mixta(
            fin_tareas + 2,
            (
                (spinner[frame % len(spinner)], spinner_estilos[frame % len(spinner_estilos)]),
                (" Trabajando...", colores["normal"]),
            ),
        )
    linea(fin_tareas + 3)
    linea(fin_tareas + 4, "Últimas líneas del proceso", colores["normal"])
    for indice, registro in enumerate(salida[-2:]):
        linea(fin_tareas + 5 + indice, f"  {registro}", colores["dim"])
    linea(fin_tareas + 7)
    _texto(stdscr, fin_tareas + 8, izquierda, "╚" + marco + "╝", ancho, colores["frame"])
    stdscr.refresh()


def _ejecutar_en_segundo_plano(accion: Accion, estado: _EstadoProceso) -> None:
    salida = _SalidaProceso(estado)
    try:
        with contextlib.redirect_stdout(salida), contextlib.redirect_stderr(salida):
            accion(estado.progreso, estado.password)
    except Exception as error:  # La UI mostrará el error sin romper curses.
        with estado.bloqueo:
            estado.error = str(error)
    finally:
        with estado.bloqueo:
            estado.terminado = True


def _pedir_contrasena(stdscr: curses.window) -> str | None:
    """Muestra un prompt de sudo seguro y visualmente integrado."""
    stdscr.clear()
    alto, ancho = stdscr.getmaxyx()
    ancho_caja = min(64, ancho - 2)
    if ancho_caja < 42:
        _texto(stdscr, max(0, alto // 2), 1, "Amplía la terminal para introducir la contraseña.", max(1, ancho - 2), curses.A_BOLD)
        stdscr.refresh()
        ancho_caja = max(20, ancho - 2)
    izquierda = max(0, (ancho - ancho_caja) // 2)
    interior = ancho_caja - 2
    marco = "═" * interior
    try:
        curses.curs_set(1)
    except curses.error:
        pass
    _texto(stdscr, max(1, alto // 2 - 5), izquierda, "╔" + marco + "╗", ancho_caja)
    _texto(stdscr, max(2, alto // 2 - 4), izquierda, "║" + " AUTORIZACIÓN DEL SISTEMA ".center(interior) + "║", ancho_caja, curses.A_BOLD)
    _texto(stdscr, max(3, alto // 2 - 3), izquierda, "║" + "Se requieren permisos de administrador".center(interior) + "║", ancho_caja, curses.A_DIM)
    _texto(stdscr, max(4, alto // 2 - 2), izquierda, "║" + "La contraseña se enviará solo a sudo".center(interior) + "║", ancho_caja, curses.A_DIM)
    _texto(stdscr, max(5, alto // 2 - 1), izquierda, "╠" + marco + "╣", ancho_caja)
    _texto(stdscr, max(6, alto // 2), izquierda, "║  Contraseña: " + " " * max(0, interior - 16) + "║", ancho_caja)
    _texto(stdscr, max(7, alto // 2 + 1), izquierda, "║  Enter confirmar · Esc cancelar".ljust(interior) + "║", ancho_caja, curses.A_DIM)
    _texto(stdscr, max(8, alto // 2 + 2), izquierda, "╚" + marco + "╝", ancho_caja)
    stdscr.refresh()

    caracteres: list[str] = []
    while True:
        tecla = stdscr.get_wch()
        if tecla in ("\n", "\r", 10, 13):
            try:
                curses.curs_set(0)
            except curses.error:
                pass
            return "".join(caracteres)
        if tecla in ("\x1b", 27):
            try:
                curses.curs_set(0)
            except curses.error:
                pass
            return None
        if tecla in (curses.KEY_BACKSPACE, "\x7f", "\b"):
            if caracteres:
                caracteres.pop()
        elif isinstance(tecla, str) and tecla.isprintable():
            caracteres.append(tecla)
        puntos = MASCARA_CONTRASENA * len(caracteres)
        linea = "║  Contraseña: " + puntos
        _texto(stdscr, max(6, alto // 2), izquierda, linea.ljust(ancho_caja - 1) + "║", ancho_caja)
        stdscr.refresh()


def _mostrar_proceso(
    stdscr: curses.window,
    accion: Accion,
    password: str | None = None,
    pedir_password: bool = False,
) -> None:
    estado = _EstadoProceso()
    estado.password = _pedir_contrasena(stdscr) if pedir_password else password
    if pedir_password and estado.password is None:
        with estado.bloqueo:
            estado.error = "Autorización cancelada"
            estado.terminado = True
        _dibujar_proceso(stdscr, estado, 0)
        stdscr.timeout(-1)
        stdscr.getch()
        return
    worker = threading.Thread(target=_ejecutar_en_segundo_plano, args=(accion, estado), daemon=True)
    inicio = time.monotonic()
    duracion_minima = 15.0
    worker.start()
    stdscr.timeout(100)
    frame = 0
    while worker.is_alive() or time.monotonic() - inicio < duracion_minima:
        if not worker.is_alive():
            with estado.bloqueo:
                estado.terminado = False
        _dibujar_proceso(stdscr, estado, frame)
        stdscr.getch()
        frame += 1
        time.sleep(0.02)
    estado.password = None
    _dibujar_proceso(stdscr, estado, frame)
    stdscr.timeout(-1)
    stdscr.getch()


def ejecutar(acciones: dict[str, Accion]) -> None:
    """Muestra el menú con curses y ejecuta la acción en segundo plano."""
    # Permite ejecutar comprobaciones automatizadas sin una terminal real.
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        opcion = sys.stdin.readline().strip()
        if opcion == "3":
            print("\nHasta luego.")
            return
        accion = acciones.get(opcion)
        if accion is not None:
            accion(lambda _tarea, _terminada=False: None, None)
        return
    while True:
        try:
            indice = _seleccionar_inquirer() if inquirer is not None else curses.wrapper(_seleccionar)
        except (curses.error, OSError) as error:
            # curses.wrapper deja la terminal restaurada antes de propagar el error.
            print(f"\nError de interfaz: {error or 'la terminal no pudo dibujarse'}")
            return
        if indice is None or indice == 2:
            print("\nHasta luego.")
            return
        accion = acciones.get(str(indice + 1))
        if accion is None:
            print("\nOpción no disponible.")
            continue
        try:
            password = curses.wrapper(_pedir_contrasena) if indice == 0 else None
        except (curses.error, OSError) as error:
            print(f"\nNo se pudo abrir el campo de contraseña: {error or 'error de terminal'}")
            continue
        if indice == 0 and password is None:
            print("\nAutorización cancelada. Volviendo al menú.")
            continue
        try:
            curses.wrapper(_mostrar_proceso, accion, password, False)
        except (curses.error, OSError) as error:
            print(f"\nLa interfaz se interrumpió: {error or 'error de terminal'}")
            continue
        print("\nLa operación terminó. Volviendo al menú...")
ESQUEMA = "org.gnome.desktop.interface"
ESQUEMA_DOCK = "org.gnome.shell.extensions.dash-to-dock"
ESQUEMA_SHELL = "org.gnome.shell.extensions.user-theme"
EXTENSION_USER_THEMES = "user-theme@gnome-shell-extensions.gcampax.github.com"
TERMINAL_PROFILE_UUID = "8b7c9f5e-2a4f-4f0c-9b3c-7e1d6a4f2c90"
MARCADOR_TRANSPARENCIA = "/* ubuntu-customizer: panel flotante transparente */"
EXTENSIONES_PRODUCTIVIDAD = (
    (779, "Clipboard Indicator"),
    (615, "AppIndicator"),
    (3843, "Just Perfection"),
    (517, "Caffeine"),
    (1319, "GSConnect"),
    (1460, "Vitals"),
)
PERFILES = {
    "wanther": {
        "nombre": "WanTher — Fullstack Angular",
        "paquetes": (
            "nodejs", "npm", "postgresql-client", "redis-tools", "docker.io",
            "docker-compose-v2", "build-essential", "python3-pip", "python3-venv",
        ),
    },
    "k3rnyx": {
        "nombre": "K3rNyx — Seguridad informática",
        "paquetes": (
            "nmap", "wireshark", "tshark", "tcpdump", "netcat-openbsd", "dnsutils",
            "whois", "traceroute", "openssl", "gnupg", "ufw", "auditd", "lynis",
            "clamav", "lsof", "strace", "gdb", "yara",
        ),
    },
}
Progreso = Callable[[str, bool], None]


def _notificar(progreso: Progreso | None, mensaje: str, terminado: bool = False) -> None:
    if progreso is not None:
        progreso(mensaje, terminado)


def _gsettings(clave: str) -> str:
    resultado = subprocess.run(
        ["gsettings", "get", ESQUEMA, clave],
        check=True,
        capture_output=True,
        text=True,
    )
    return resultado.stdout.strip()


def _dconf_write(ruta: str, valor: str, *, dry_run: bool = False) -> None:
    ejecutar_comando(["dconf", "write", ruta, valor], dry_run=dry_run)


def configurar_gnome_terminal(*, dry_run: bool = False, progreso: Progreso | None = None) -> None:
    """Configura la terminal predeterminada de Ubuntu sin instalar otra."""
    if not dry_run:
        comprobar_comando("dconf")
        esquemas = subprocess.run(
            ["gsettings", "list-schemas"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        if "org.gnome.Terminal.Legacy.Profile" not in esquemas:
            print("\nAviso: no se encontró GNOME Terminal; se conserva la terminal actual.")
            _notificar(progreso, "Perfil GNOME Terminal", True)
            return
    _notificar(progreso, "Perfil GNOME Terminal")

    base = "/org/gnome/terminal/legacy/profiles:/"
    perfil = f"{base}:{TERMINAL_PROFILE_UUID}/"
    if dry_run:
        lista = ""
    else:
        lista = subprocess.run(
            ["dconf", "read", f"{base}list"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    if TERMINAL_PROFILE_UUID not in lista:
        ids = lista.strip()[1:-1].strip() if lista.startswith("[") and lista.endswith("]") else ""
        nueva_lista = f"[{ids}, '{TERMINAL_PROFILE_UUID}']" if ids else f"['{TERMINAL_PROFILE_UUID}']"
        _dconf_write(f"{base}list", nueva_lista, dry_run=dry_run)

    colores = {
        "visible-name": "'TokyoNight Storm'",
        "use-theme-colors": "false",
        "background-color": "'#1a1b26'",
        "foreground-color": "'#c0caf5'",
        "bold-color": "'#bb9af7'",
        "bold-color-same-as-fg": "false",
        "palette": "['#16161e', '#f7768e', '#73daca', '#e0af68', '#7aa2f7', '#bb9af7', '#7dcfff', '#c0caf5', '#414868', '#f7768e', '#73daca', '#e0af68', '#7aa2f7', '#bb9af7', '#7dcfff', '#c0caf5']",
        "use-system-font": "false",
        "font": "'JetBrainsMono Nerd Font Mono 11'",
    }
    for clave, valor in colores.items():
        _dconf_write(f"{perfil}{clave}", valor, dry_run=dry_run)
    _dconf_write(f"{base}default", f"'{TERMINAL_PROFILE_UUID}'", dry_run=dry_run)
    _notificar(progreso, "Perfil GNOME Terminal", True)
    print("\nPerfil GNOME Terminal aplicado: TokyoNight Storm")


def _ejecutar_opcional(comando: list[str], *, dry_run: bool = False) -> None:
    """Ejecuta un ajuste opcional sin detener el tema si GNOME no lo soporta."""
    if dry_run:
        ejecutar_comando(comando, dry_run=True)
        return
    resultado = subprocess.run(comando, capture_output=True, text=True)
    if resultado.returncode != 0:
        detalle = resultado.stderr.strip() or "clave no disponible en esta versión de GNOME"
        print(f"Aviso: no se pudo aplicar {' '.join(comando[2:])}: {detalle}")


def habilitar_user_themes(*, dry_run: bool = False) -> None:
    """Activa la extensión GNOME que permite seleccionar temas de Shell."""
    comprobar_comando("gnome-extensions")
    print("\nHabilitando la extensión user-themes")
    _ejecutar_opcional(
        ["gnome-extensions", "enable", EXTENSION_USER_THEMES],
        dry_run=dry_run,
    )


def _clonar_si_falta(repositorio: str, destino: Path, *, dry_run: bool = False) -> None:
    if destino.exists():
        return
    comando = ["git", "clone", "--depth", "1", repositorio, str(destino)]
    if dry_run:
        ejecutar_comando(comando, dry_run=True)
        return
    subprocess.run(comando, check=True, capture_output=True, text=True)


def _prompt_personalizado(perfil: str) -> str:
    """Devuelve un prompt Zsh contextual para el perfil seleccionado."""
    contexto = """
_ubuntu_prompt_context() {
    local contexto=""
    local version_node=""

    if [[ -n "$VIRTUAL_ENV" ]]; then
        contexto+=" %F{#c0caf5}via%f %F{#e0af68}🐍 ${VIRTUAL_ENV:t}%f"
    elif [[ -f pyproject.toml || -f requirements.txt || -f manage.py ]]; then
        contexto+=" %F{#c0caf5}via%f %F{#e0af68}🐍 python%f"
    fi

    if [[ -f package.json || -f pnpm-lock.yaml || -f yarn.lock || -f package-lock.json ]]; then
        if (( $+commands[node] )); then
            version_node=$(node --version 2>/dev/null)
            version_node=${version_node#v}
            contexto+=" %F{#c0caf5}via%f %F{#9ece6a}⬢ ${version_node}%f"
        else
            contexto+=" %F{#c0caf5}via%f %F{#9ece6a}⬢ node%f"
        fi
        [[ -f pnpm-lock.yaml ]] && contexto+=" %F{#c0caf5}is%f %F{#bb9af7}📦 pnpm%f"
        [[ -f yarn.lock ]] && contexto+=" %F{#c0caf5}is%f %F{#bb9af7}📦 yarn%f"
        [[ -f package-lock.json ]] && contexto+=" %F{#c0caf5}is%f %F{#bb9af7}📦 npm%f"
    fi

    if [[ -f compose.yaml || -f compose.yml || -f docker-compose.yaml || -f docker-compose.yml ]]; then
        contexto+=" %F{#c0caf5}via%f %F{#7dcfff}🐳 docker%f"
    fi

    if [[ "$UBUNTU_CUSTOMIZER_PROFILE" == "k3rnyx" ]]; then
        [[ -n "$SSH_CONNECTION" ]] && contexto+=" %F{#c0caf5}over%f %F{#7dcfff}ssh%f"
        (( EUID == 0 )) && contexto+=" %F{#f7768e}root%f"
    fi

    PROMPT_CONTEXT="$contexto"
}

setopt prompt_subst
setopt prompt_percent

# Símbolos predeterminados de git_status en Spaceship Prompt.
ZSH_THEME_GIT_PROMPT_UNTRACKED='?'
ZSH_THEME_GIT_PROMPT_ADDED='+'
ZSH_THEME_GIT_PROMPT_MODIFIED='!'
ZSH_THEME_GIT_PROMPT_RENAMED='»'
ZSH_THEME_GIT_PROMPT_DELETED='✘'
ZSH_THEME_GIT_PROMPT_STASHED='$'
ZSH_THEME_GIT_PROMPT_UNMERGED='='
ZSH_THEME_GIT_PROMPT_AHEAD='⇡'
ZSH_THEME_GIT_PROMPT_BEHIND='⇣'
ZSH_THEME_GIT_PROMPT_DIVERGED='⇕'

_ubuntu_prompt_git() {
    local rama=""
    local estado=""
    PROMPT_GIT=""

    if (( $+functions[git_current_branch] )); then
        rama=$(git_current_branch 2>/dev/null)
    else
        rama=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) || \
            rama=$(command git rev-parse --short HEAD 2>/dev/null)
    fi
    [[ -z "$rama" ]] && return

    if (( $+functions[_omz_git_prompt_status] )); then
        estado=$(_omz_git_prompt_status 2>/dev/null)
    fi

    PROMPT_GIT=" %F{#c0caf5}on%f %F{#bb9af7} ${rama}%f"
    [[ -n "$estado" ]] && PROMPT_GIT+=" %F{#f7768e}[${estado}]%f"
}

precmd() {
    local estado=$?
    _ubuntu_prompt_git
    _ubuntu_prompt_context
    return $estado
}
"""
    if perfil == "wanther":
        return (
            f"{PROMPT_MARKER_START}\n"
            "# WanTher: desarrollo Fullstack\n"
            f"{contexto}"
            "UBUNTU_CUSTOMIZER_PROFILE=wanther\n"
            "PROMPT='%F{#7dcfff}󰖟 WanTher%f %F{#7aa2f7}%2~%f${PROMPT_GIT}${PROMPT_CONTEXT}%(?.. %F{#f7768e}✘ %?%f)\n%F{#9ece6a}❯%f '\n"
            f"{PROMPT_MARKER_END}\n"
        )
    if perfil == "k3rnyx":
        return (
            f"{PROMPT_MARKER_START}\n"
            "# K3rNyx: seguridad informática\n"
            f"{contexto}"
            "UBUNTU_CUSTOMIZER_PROFILE=k3rnyx\n"
            "PROMPT='%F{#bb9af7}⛧ K3rNyx%f %F{#f7768e}%n%f%F{#e0af68}㉿%f%F{#7dcfff}%m%f %F{#7aa2f7}%2~%f${PROMPT_GIT}${PROMPT_CONTEXT}%(?.. %F{#f7768e}✘ %?%f)\n%(!.%F{#f7768e}#%f.%F{#f7768e}☠%f) '\n"
            f"{PROMPT_MARKER_END}\n"
        )
    raise RuntimeError(f"Perfil no reconocido: {perfil}")


def configurar_zsh(
    *, dry_run: bool = False, progreso: Progreso | None = None, perfil: str = "wanther"
) -> None:
    """Instala Zsh, Oh My Zsh y plugins productivos de forma idempotente."""
    _notificar(progreso, "Zsh, Oh My Zsh y fuente Nerd")
    if not dry_run:
        comprobar_comando("git")
        comprobar_comando("zsh")

    _clonar_si_falta(OH_MY_ZSH_REPO, OH_MY_ZSH_DIR, dry_run=dry_run)
    for nombre, repositorio in ZSH_PLUGIN_REPOS.items():
        _clonar_si_falta(repositorio, ZSH_CUSTOM_DIR / "plugins" / nombre, dry_run=dry_run)

    plugins = (
        "git gitfast sudo colored-man-pages extract z fzf docker docker-compose "
        "node npm python zsh-completions zsh-autosuggestions zsh-syntax-highlighting"
    )
    bloque = (
        f"{ZSH_MARKER_START}\n"
        'export ZSH="$HOME/.oh-my-zsh"\n'
        'ZSH_THEME=""\n'
        f"plugins=({plugins})\n"
        "HIST_STAMPS=\"yyyy-mm-dd\"\n"
        "setopt hist_ignore_dups share_history\n"
        "if (( $+commands[zoxide] )); then\n"
        "  eval \"$(zoxide init zsh)\"\n"
        "fi\n"
        "if (( $+commands[eza] )); then\n"
        "  alias ls='eza --group-directories-first'\n"
        "  alias ll='eza -lah --git --group-directories-first'\n"
        "  alias la='eza -a --group-directories-first'\n"
        "fi\n"
        "alias c='clear'\n"
        "alias ..='cd ..'\n"
        "alias ...='cd ../..'\n"
        f"{ZSH_MARKER_END}\n"
    )
    prompt = _prompt_personalizado(perfil)
    zshrc = Path.home() / ".zshrc"
    if dry_run:
        print(f"\nConfigurar {zshrc} con plugins: {plugins} y prompt {perfil}")
    else:
        contenido = zshrc.read_text(encoding="utf-8") if zshrc.exists() else ""
        for inicio_marcador, fin_marcador in (
            (ZSH_MARKER_START, ZSH_MARKER_END),
            (PROMPT_MARKER_START, PROMPT_MARKER_END),
        ):
            if inicio_marcador in contenido and fin_marcador in contenido:
                inicio = contenido.index(inicio_marcador)
                fin = contenido.index(fin_marcador, inicio) + len(fin_marcador)
                contenido = contenido[:inicio] + contenido[fin:].lstrip("\n")
        if zshrc.exists() and not (zshrc.with_suffix(".zshrc.ubuntu-customizer.bak")).exists():
            shutil.copy2(zshrc, zshrc.with_suffix(".zshrc.ubuntu-customizer.bak"))
        fuente_omz = "source $ZSH/oh-my-zsh.sh"
        if fuente_omz in contenido:
            contenido = contenido.replace(fuente_omz, bloque + "\n" + fuente_omz + "\n\n" + prompt, 1)
        else:
            contenido = bloque + "\n" + 'export ZSH="$HOME/.oh-my-zsh"\n' + fuente_omz + "\n\n" + prompt + contenido
        zshrc.write_text(contenido, encoding="utf-8")

    zsh_path = shutil.which("zsh")
    if not dry_run and zsh_path and os.environ.get("SHELL") != zsh_path:
        resultado = subprocess.run(["chsh", "-s", zsh_path], capture_output=True, text=True)
        if resultado.returncode != 0:
            print(f"Aviso: no se pudo establecer Zsh como shell predeterminado: {resultado.stderr.strip()}")
    _notificar(progreso, "Zsh, Oh My Zsh y fuente Nerd", True)


def instalar_jetbrains_mono_nerd(*, dry_run: bool = False) -> None:
    """Instala JetBrains Mono Nerd Font para iconos del prompt y terminal."""
    print("\nInstalando JetBrains Mono Nerd Font")
    if dry_run:
        ejecutar_comando(["curl", "-L", NERD_FONT_URL], dry_run=True)
        print(f"  destino: {FONT_DIR}")
        return
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="ubuntu-customizer-font-") as temporal:
        archivo = Path(temporal) / "JetBrainsMono.tar.xz"
        urlretrieve(NERD_FONT_URL, archivo)
        subprocess.run(["tar", "-xJf", str(archivo), "-C", str(FONT_DIR)], check=True)
    comprobar_comando("fc-cache")
    subprocess.run(["fc-cache", "-f", str(FONT_DIR)], check=True, capture_output=True, text=True)


def configurar_entorno_terminal(
    *, dry_run: bool = False, progreso: Progreso | None = None, perfil: str = "wanther"
) -> None:
    configurar_zsh(dry_run=dry_run, progreso=progreso, perfil=perfil)
    instalar_jetbrains_mono_nerd(dry_run=dry_run)


def _tema_tokyonight_instalado() -> str | None:
    carpetas = [Path.home() / ".themes", Path.home() / ".local/share/themes"]
    candidatos = [
        carpeta.name
        for base in carpetas
        if base.exists()
        for carpeta in base.iterdir()
        if carpeta.is_dir() and "tokyonight" in carpeta.name.lower()
    ]
    candidatos.sort(key=lambda nombre: ("storm" not in nombre.lower(), nombre.lower()))
    return candidatos[0] if candidatos else None


def _ruta_tema_instalado(nombre: str) -> Path | None:
    for base in (Path.home() / ".themes", Path.home() / ".local/share/themes"):
        ruta = base / nombre
        if ruta.is_dir():
            return ruta
    return None


def copiar_gtk4(*, dry_run: bool = False) -> None:
    """Copia los archivos GTK4 del tema a ~/.config/gtk-4.0."""
    tema = _tema_tokyonight_instalado()
    if tema is None:
        raise RuntimeError("No se encontró una instalación de TokyoNight en ~/.themes.")
    origen = _ruta_tema_instalado(tema)
    gtk4 = origen / "gtk-4.0" if origen else None
    destino = Path.home() / ".config/gtk-4.0"
    archivos = ("gtk.css", "gtk-dark.css")
    if gtk4 is None or not gtk4.is_dir():
        raise RuntimeError("La instalación de TokyoNight no contiene una carpeta gtk-4.0.")

    print(f"\nCopiando archivos GTK4 a {destino}")
    if dry_run:
        print(f"  - {gtk4 / 'assets'}")
        for archivo in archivos:
            print(f"  - {gtk4 / archivo}")
        return

    destino.mkdir(parents=True, exist_ok=True)
    assets = gtk4 / "assets"
    destino_assets = destino / "assets"
    if assets.is_dir() and not (
        destino_assets.is_symlink() and destino_assets.resolve() == assets.resolve()
    ):
        if destino_assets.is_symlink():
            destino_assets.unlink()
        shutil.copytree(assets, destino_assets, dirs_exist_ok=True, symlinks=True)
    for archivo in archivos:
        origen_archivo = gtk4 / archivo
        if origen_archivo.is_file():
            destino_archivo = destino / archivo
            if destino_archivo.is_symlink() and destino_archivo.resolve() == origen_archivo.resolve():
                continue
            if destino_archivo.is_symlink():
                destino_archivo.unlink()
            shutil.copy2(origen_archivo, destino_archivo)


def aplicar_transparencia_shell(nombre: str, *, dry_run: bool = False) -> None:
    """Hace semitransparente el panel de GNOME Shell del tema instalado."""
    ruta_css = _ruta_tema_instalado(nombre)
    css = ruta_css / "gnome-shell/gnome-shell.css" if ruta_css else None
    if css is None or not css.is_file():
        raise RuntimeError("La instalación de TokyoNight no contiene el CSS de GNOME Shell.")

    regla = f"""
{MARCADOR_TRANSPARENCIA}
#panel {{
    background-color: rgba(26, 27, 38, 0.78) !important;
    background-image: none !important;
    box-shadow: none !important;
}}
"""
    print(f"\nAplicando transparencia al panel: {css}")
    if dry_run:
        return

    contenido = css.read_text(encoding="utf-8")
    if MARCADOR_TRANSPARENCIA in contenido:
        contenido = contenido.split(MARCADOR_TRANSPARENCIA, 1)[0].rstrip() + "\n"
    css.write_text(contenido + regla, encoding="utf-8")


def aplicar_iconos_sea(*, dry_run: bool = False) -> None:
    """Activa los iconos Deepin SEA instalados con deepin-icon-theme."""
    _ejecutar_opcional(
        ["gsettings", "set", ESQUEMA, "icon-theme", "Sea"],
        dry_run=dry_run,
    )
    print("\nIconos disponibles: Deepin SEA")


def reducir_iconos_sea(
    *, dry_run: bool = False, progreso: Progreso | None = None, sudo_password: str | None = None
) -> None:
    """Conserva únicamente los iconos de carpetas del tema SEA."""
    ejecutar_comando(
        [
            "sudo",
            "find",
            "/usr/share/icons/Sea",
            "-mindepth",
            "1",
            "!",
            "-path",
            "/usr/share/icons/Sea/places",
            "!",
            "-path",
            "/usr/share/icons/Sea/places/scalable",
            "!",
            "-path",
            "/usr/share/icons/Sea/index.theme",
            "!",
            "-path",
            "/usr/share/icons/Sea/places/scalable/folder*.svg",
            "-delete",
        ],
        dry_run=dry_run,
        sudo_password=sudo_password,
    )
    _notificar(progreso, "Iconos Deepin SEA", True)


def instalar_extensiones_productividad(*, dry_run: bool = False, progreso: Progreso | None = None) -> None:
    """Instala extensiones compatibles con la versión actual de GNOME Shell."""
    if dry_run:
        for _, nombre in EXTENSIONES_PRODUCTIVIDAD:
            print(f"$ instalar extensión: {nombre}")
        return

    _notificar(progreso, "Extensiones de productividad")

    comprobar_comando("gnome-extensions")
    version = subprocess.run(
        ["gnome-shell", "--version"], check=True, capture_output=True, text=True
    ).stdout
    coincidencia = re.search(r"(\d+)", version)
    if coincidencia is None:
        raise RuntimeError(f"No se pudo detectar la versión de GNOME Shell: {version.strip()}")
    version_shell = coincidencia.group(1)

    for pk, nombre in EXTENSIONES_PRODUCTIVIDAD:
        try:
            api = (
                "https://extensions.gnome.org/extension-info/"
                f"?pk={pk}&shell_version={version_shell}"
            )
            solicitud = Request(
                api,
                headers={"User-Agent": "ubuntu-customizer/1.0 (+GNOME extension installer)"},
            )
            with urlopen(solicitud, timeout=30) as respuesta:
                datos = json.load(respuesta)
            if datos.get("error"):
                raise RuntimeError(str(datos["error"]))
            descarga = datos.get("download_url")
            uuid = datos.get("uuid")
            if not descarga or not uuid:
                raise RuntimeError("no hay una versión compatible disponible")
            with tempfile.TemporaryDirectory(prefix="ubuntu-customizer-ext-") as temporal:
                archivo = Path(temporal) / f"{uuid}.zip"
                url_descarga = urljoin("https://extensions.gnome.org", descarga)
                solicitud_descarga = Request(
                    url_descarga,
                    headers={"User-Agent": "ubuntu-customizer/1.0 (+GNOME extension installer)"},
                )
                with urlopen(solicitud_descarga, timeout=60) as respuesta, archivo.open("wb") as salida:
                    shutil.copyfileobj(respuesta, salida)
                if archivo.stat().st_size == 0:
                    raise RuntimeError("el archivo descargado está vacío")
                resultado = subprocess.run(
                    ["gnome-extensions", "install", "--force", str(archivo)],
                    capture_output=True,
                    text=True,
                )
                if resultado.returncode != 0:
                    detalle = resultado.stderr.strip() or resultado.stdout.strip()
                    raise RuntimeError(f"falló la instalación: {detalle}")
            if resultado.stdout:
                print(resultado.stdout, end="")
            if resultado.stderr:
                print(resultado.stderr, end="")
            instaladas = subprocess.run(
                ["gnome-extensions", "list"], capture_output=True, text=True, check=True
            ).stdout.splitlines()
            if uuid not in instaladas:
                raise RuntimeError("GNOME no confirmó la extensión instalada")
            activacion = subprocess.run(
                ["gnome-extensions", "enable", uuid],
                capture_output=True,
                text=True,
            )
            if activacion.returncode != 0:
                detalle = activacion.stderr.strip() or activacion.stdout.strip()
                print(f"Aviso: {nombre} quedó instalada pero no se pudo activar: {detalle}")
                continue
            print(f"Extensión instalada: {nombre}")
        except (HTTPError, URLError, OSError, ValueError, subprocess.CalledProcessError, RuntimeError) as error:
            print(f"Aviso: no se pudo instalar {nombre}: {error}")
    _notificar(progreso, "Extensiones de productividad", True)


def configurar_ubuntu_dock(*, dry_run: bool = False, progreso: Progreso | None = None) -> None:
    """Aplica la configuración de productividad del Ubuntu Dock."""
    _notificar(progreso, "Ubuntu Dock")
    ajustes = (
        ("dock-position", "'BOTTOM'"),
        ("dock-fixed", "false"),
        ("autohide", "true"),
        ("autohide-in-fullscreen", "true"),
        ("intellihide", "true"),
        ("intellihide-mode", "'ALL_WINDOWS'"),
        ("dash-max-icon-size", "34"),
        ("icon-size-fixed", "false"),
        ("extend-height", "false"),
        ("transparency-mode", "'FIXED'"),
        ("background-opacity", "0.0"),
        ("show-favorites", "true"),
        ("show-show-apps-button", "true"),
        ("show-icons-notifications-counter", "true"),
        ("show-windows-preview", "true"),
        ("click-action", "'focus-or-appspread'"),
        ("scroll-action", "'switch-workspace'"),
    )
    for clave, valor in ajustes:
        _ejecutar_opcional(
            ["gsettings", "set", ESQUEMA_DOCK, clave, valor],
            dry_run=dry_run,
        )
    print("\nConfiguración de Ubuntu Dock aplicada")
    _notificar(progreso, "Ubuntu Dock", True)


def mostrar_tema() -> None:
    comprobar_comando("gsettings")
    print("\nTema actual:")
    print(f"  Esquema de color: {_gsettings('color-scheme')}")
    print(f"  Alto contraste:   {_gsettings('high-contrast')}")
    print(f"  Tema GTK:          {_gsettings('gtk-theme')}")
    print(f"  Tema de iconos:    {_gsettings('icon-theme')}")
    print(f"  Cursor:             {_gsettings('cursor-theme')}")


def instalar_tokyonight_storm(
    *,
    dry_run: bool = False,
    progreso: Progreso | None = None,
    sudo_password: str | None = None,
    perfil: str = "wanther",
) -> None:
    """Instala dependencias, descarga el tema y activa su variante Storm."""
    destino = Path.home() / CARPETA_INSTALACION
    if perfil not in PERFILES:
        raise RuntimeError(f"Perfil no reconocido: {perfil}")
    dependencias = [
        "git",
        "gnome-shell",
        "gnome-shell-extensions",
        "gnome-shell-ubuntu-extensions",
        "gnome-shell-extension-manager",
        "gnome-tweaks",
        "sassc",
        "gtk2-engines-murrine",
        "gnome-themes-extra",
        "dconf-cli",
        "zsh",
        "curl",
        "fontconfig",
        "fzf",
        "tmux",
        "direnv",
        "ripgrep",
        "fd-find",
        "bat",
        "jq",
        "zoxide",
        "eza",
        "btop",
        "tealdeer",
        "neovim",
        "shellcheck",
        "shfmt",
        "deepin-icon-theme",
        "papirus-icon-theme",
        "libglib2.0-bin",
        *PERFILES[perfil]["paquetes"],
    ]
    print(f"\nPerfil seleccionado: {PERFILES[perfil]['nombre']}")
    _notificar(progreso, "Dependencias del sistema")
    faltantes = _dependencias_faltantes(dependencias)
    if faltantes:
        ejecutar_comando(
            ["sudo", "apt-get", "install", "-y", *faltantes],
            dry_run=dry_run,
            sudo_password=sudo_password,
        )
    else:
        print("\nTodas las dependencias del sistema ya están instaladas.")
    _notificar(progreso, "Dependencias del sistema", True)
    configurar_entorno_terminal(dry_run=dry_run, progreso=progreso, perfil=perfil)
    reducir_iconos_sea(
        dry_run=dry_run,
        progreso=progreso,
        sudo_password=sudo_password,
    )
    instalar_extensiones_productividad(dry_run=dry_run, progreso=progreso)
    configurar_ubuntu_dock(dry_run=dry_run, progreso=progreso)
    if not destino.exists():
        ejecutar_comando(["git", "clone", "--depth", "1", REPOSITORIO_TOKYONIGHT, str(destino)], dry_run=dry_run)
    comando_instalacion = [
        "bash",
        "install.sh",
        "--tweaks",
        "storm",
        "macos",
        "float",
        "-l",
    ]
    instalador = destino / "themes"
    if not dry_run and not (instalador / "install.sh").is_file():
        raise RuntimeError(f"No se encontró el instalador en {instalador / 'install.sh'}")
    if dry_run:
        ejecutar_comando(comando_instalacion, dry_run=True)
        print("\nSe instalaría TokyoNight GTK con la variante Storm, shell flotante y sin outline.")
        return
    comprobar_comando("git")
    comprobar_comando("gnome-shell")
    comprobar_comando("gnome-tweaks")
    resultado = subprocess.run(
        comando_instalacion,
        cwd=instalador,
        capture_output=True,
        text=True,
    )
    if resultado.returncode != 0:
        detalle = resultado.stderr.strip() or resultado.stdout.strip()
        raise RuntimeError(
            f"El instalador TokyoNight falló con código {resultado.returncode}.\n{detalle}"
        )
    copiar_gtk4()
    aplicar_tokyonight_storm(progreso=progreso)


def aplicar_tokyonight_storm(*, dry_run: bool = False, progreso: Progreso | None = None) -> None:
    """Activa TokyoNight Storm si ya está instalado."""
    comprobar_comando("gsettings")
    comprobar_comando("gnome-shell")
    comprobar_comando("gnome-tweaks")
    tema = _tema_tokyonight_instalado()
    if tema is None:
        raise RuntimeError("TokyoNight no está instalado. Usa primero la opción de instalación.")
    _notificar(progreso, "Tema TokyoNight")
    ejecutar_comando(["gsettings", "set", ESQUEMA, "gtk-theme", tema], dry_run=dry_run)
    # El tema GTK y el tema de GNOME Shell son ajustes independientes.
    habilitar_user_themes(dry_run=dry_run)
    _ejecutar_opcional(
        ["gsettings", "set", ESQUEMA_SHELL, "name", tema],
        dry_run=dry_run,
    )
    _ejecutar_opcional(
        ["gsettings", "set", ESQUEMA, "color-scheme", "prefer-dark"],
        dry_run=dry_run,
    )
    _ejecutar_opcional(
        ["gsettings", "set", ESQUEMA, "high-contrast", "false"],
        dry_run=dry_run,
    )
    copiar_gtk4(dry_run=dry_run)
    _notificar(progreso, "Tema TokyoNight", True)
    _notificar(progreso, "Shell flotante y transparencia")
    aplicar_transparencia_shell(tema, dry_run=dry_run)
    _notificar(progreso, "Shell flotante y transparencia", True)
    aplicar_iconos_sea(dry_run=dry_run)
    _notificar(progreso, "Iconos Deepin SEA", True)
    configurar_gnome_terminal(dry_run=dry_run, progreso=progreso)
    configurar_ubuntu_dock(dry_run=dry_run, progreso=progreso)
    print(f"\nTema aplicado: {tema} (TokyoNight Storm, botones macOS, sin outline)")
def argumentos() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Personaliza el tema visual de Ubuntu")
    parser.add_argument(
        "--tema",
        choices=("tokyonight-storm", "mostrar"),
        help="Aplica un tema o muestra la configuración actual",
    )
    parser.add_argument("--dry-run", action="store_true", help="Solo muestra lo que se haría")
    parser.add_argument(
        "--perfil",
        choices=tuple(PERFILES),
        default="wanther",
        help="Perfil de instalación: wanther o k3rnyx",
    )
    return parser.parse_args()


def main() -> int:
    args = argumentos()
    try:
        comprobar_ubuntu()
        if args.tema == "tokyonight-storm":
            instalar_tokyonight_storm(
                dry_run=args.dry_run,
                progreso=progreso_cli,
                perfil=args.perfil,
            )
        elif args.tema == "mostrar":
            mostrar_tema()
        elif args.tema:
            instalar_tokyonight_storm(dry_run=args.dry_run)
        else:
            ejecutar({
                "1": lambda progreso, password: instalar_tokyonight_storm(
                    dry_run=args.dry_run,
                    progreso=progreso,
                    sudo_password=password,
                    perfil=args.perfil,
                ),
                "2": lambda _progreso, _password: mostrar_tema(),
            })
        return 0
    except (RuntimeError, subprocess.CalledProcessError, EOFError, KeyboardInterrupt, curses.error, OSError) as error:
        return error_fatal(error)

if __name__ == "__main__":

    raise SystemExit(main())
