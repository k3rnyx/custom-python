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
```

Perfiles disponibles desde el menú:

- `WanTher`: desarrollo Fullstack Angular, Node.js, Docker, PostgreSQL y Redis.
- `K3rNyx`: seguridad informática, análisis de red y herramientas de laboratorio.

El menú Bash es la interfaz principal y delega la lógica de instalación y configuración al motor Python. La personalización también crea y activa un perfil `TokyoNight Storm` para GNOME Terminal.

La configuración global instala Zsh, Oh My Zsh, autocompletado, autosugerencias, resaltado de sintaxis, integraciones para Git, Node, npm, Docker, Python y fzf, además de JetBrains Mono Nerd Font.

El menú visual reutiliza los componentes ASCII/ANSI de `lib/`, adaptados del proyecto `script-custom-ubuntu-gnome`.

Al iniciar, `app/setup.sh` instala primero las dependencias de Python y las dependencias de sistema de ambos perfiles. El menú se muestra únicamente cuando esa preparación termina correctamente.
