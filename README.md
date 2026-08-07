# Ubuntu Customizer CLI

Aplicación de línea de comandos para personalizar GNOME en Ubuntu.

## Estructura

```text
.
├── ubuntu-customizer.sh     # Punto de entrada y menú
├── lib/
│   ├── ui.sh                 # Colores, marcos, logs y barra de progreso
│   └── banner.sh             # Banners ASCII Tokyo Night con fallback
├── app/
│   ├── ubuntu_customizer.py   # Motor de la aplicación
│   ├── setup.sh               # Preparación del entorno Python
│   └── requirements.txt       # Dependencias Python
└── .venv/                     # Entorno virtual local generado automáticamente
```

## Uso

```bash
./ubuntu-customizer.sh
./ubuntu-customizer.sh --tema
./ubuntu-customizer.sh --mostrar
./ubuntu-customizer.sh --dry-run --tema
./ubuntu-customizer.sh --restore
```

Perfiles disponibles desde el menú:

- `WanTher`: desarrollo Fullstack Angular, Node.js, Docker, PostgreSQL y Redis. También prepara pnpm, Angular CLI, herramientas de compilación y aliases básicos de Git.
- `K3rNyx`: seguridad informática, análisis de red, auditoría web y herramientas de laboratorio. Crea `~/Security` con carpetas para reconocimiento, capturas, reportes, laboratorios y wordlists.

El menú Bash es la interfaz principal y delega la lógica de instalación y configuración al motor Python. La personalización configura el perfil `TokyoNight Storm` en la terminal predeterminada de Ubuntu (GNOME Terminal), si ya está instalada. No instala ni reemplaza ningún emulador de terminal.

La configuración global instala Zsh, Oh My Zsh, autocompletado, autosugerencias, resaltado de sintaxis, integraciones para Git, Node, npm, Docker, Python y fzf, además de JetBrains Mono Nerd Font.

Cada perfil instala únicamente sus dependencias específicas. WanTher instala pnpm y Angular CLI mediante npm, mientras que K3rNyx intenta incluir herramientas adicionales como Aircrack-ng, SQLMap, Hydra, John, Nikto y Proxychains4; las que no estén disponibles en los repositorios se omiten como opcionales. UFW no se activa automáticamente para no cortar conexiones existentes.

El menú visual reutiliza los componentes ASCII/ANSI de `lib/`, adaptados del proyecto `script-custom-ubuntu-gnome`.

Al iniciar, `app/setup.sh` instala las dependencias comunes y las del perfil seleccionado antes de mostrar el menú. Las aplicaciones grandes (VS Code, Firefox Nightly y OpenCode) se preparan solo para WanTher.

Antes de modificar paquetes o la configuración del usuario se crea un respaldo en `~/.local/state/ubuntu-customizer/backups/` (o bajo `XDG_STATE_HOME` si está definido). Incluye también `.gitconfig` y `.npmrc`. Para restaurar el más reciente usa `./ubuntu-customizer.sh --restore`. El registro de operaciones queda en `~/.local/state/ubuntu-customizer/ubuntu-customizer.log`. La restauración cubre archivos de configuración y ajustes dconf respaldados; no desinstala paquetes, extensiones, temas ni fuentes.
