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
# Solo si deseas cambiar el shell de inicio a Zsh
./ubuntu-customizer.sh --tema --perfil k3rnyx --zsh-default
```

Perfiles disponibles desde el menú:

- `WanTher`: desarrollo Fullstack Angular, Node.js, Docker, PostgreSQL y Redis. También prepara pnpm, Angular CLI, herramientas de compilación y aliases básicos de Git.
- `K3rNyx`: seguridad informática, análisis de red, auditoría web y herramientas de laboratorio. Crea `~/Security` con carpetas para reconocimiento, capturas, reportes, laboratorios y wordlists.

El menú Bash es la interfaz principal y delega la lógica de instalación y configuración al motor Python. La personalización configura el perfil `Tokyo Night Storm` en Ptyxis, la terminal predeterminada de Ubuntu. No instala ni reemplaza ningún emulador de terminal.

La configuración global instala Zsh, Oh My Zsh, autocompletado, autosugerencias, resaltado de sintaxis, integraciones para Git, Node, npm, Docker, Python y fzf, además de JetBrains Mono Nerd Font. Zsh no reemplaza el shell predeterminado automáticamente; usa `--zsh-default` si quieres solicitar ese cambio.

La personalización también aplica un tema GRUB TokyoNight: menú visible, cinco segundos de espera, colores TokyoNight y un tema en `/boot/grub/themes/ubuntu-customizer/theme.txt`. Se guarda una copia de `/etc/default/grub` dentro del respaldo previo.

El instalador elimina cualquier tema TokyoNight anterior encontrado en `~/.themes` y `~/.local/share/themes`, y conserva únicamente la variante original TokyoNight Storm, con sus versiones clara y oscura estándar y archivos GTK3, GTK4 y GNOME Shell. Los temas que no sean TokyoNight no se modifican.

También personaliza el login GDM3 mediante un banner `Ubuntu Customizer · TokyoNight Storm`, instala el tema GTK TokyoNight en `/usr/share/themes/` para que GDM pueda verlo, aplica colores oscuros, paneles transparentes sin outline y usa una imagen real de la colección TokyoNight como fondo en `/usr/share/backgrounds/ubuntu-customizer/`. El mismo estilo se aplica al bloqueo y la colección se utiliza como fondo del menú GRUB. Usa la configuración dconf oficial de GNOME; el cambio se aplica al siguiente inicio de sesión y no reinicia GDM automáticamente.

Además descarga y conserva toda la colección de wallpapers TokyoNight en `~/.local/share/backgrounds/TokyoNight`, genera un manifiesto y configura una rotación dinámica de todas las imágenes para el escritorio y la pantalla de bloqueo. También configura fuentes GNOME con JetBrains Mono para texto monoespaciado, escalado 1.0 y atajos `Ctrl+Alt+T` para la terminal y `Super+E` para Archivos. Los atajos existentes se conservan.

El Ubuntu Dock se replica con la configuración de referencia y fija estas aplicaciones, en este orden: Ptyxis, Visual Studio Code, Archivos, Firefox Nightly y Firefox.

También añade logo TokyoNight al login, instala y selecciona Material Light Cursor, configura bloqueo de pantalla, animaciones, ahorro de energía y un tema Plymouth TokyoNight con regeneración de initramfs. No modifica el tema de iconos del sistema.

El sonido también se adapta al perfil con temas propios generados localmente en `~/.local/share/sounds/`: WanTher usa `UbuntuCustomizer-WanTher` con tonos cálidos y K3rNyx usa `UbuntuCustomizer-K3rNyx` con tonos graves y discretos. Ambos heredan eventos no personalizados de `freedesktop`.

Cada perfil instala únicamente sus dependencias específicas. WanTher instala pnpm y Angular CLI mediante npm, mientras que K3rNyx intenta incluir herramientas adicionales como Aircrack-ng, SQLMap, Hydra, John, Nikto y Proxychains4; las que no estén disponibles en los repositorios se omiten como opcionales. UFW no se activa automáticamente para no cortar conexiones existentes.

El menú visual reutiliza los componentes ASCII/ANSI de `lib/`, adaptados del proyecto `script-custom-ubuntu-gnome`.

Al iniciar, `app/setup.sh` instala las dependencias comunes y las del perfil seleccionado antes de mostrar el menú. Las aplicaciones grandes (VS Code, Firefox Nightly y OpenCode) se preparan solo para WanTher.

Antes de modificar paquetes o la configuración del usuario se crea un respaldo en `~/.local/state/ubuntu-customizer/backups/` (o bajo `XDG_STATE_HOME` si está definido). Incluye también `.gitconfig` y `.npmrc`. Para restaurar el más reciente usa `./ubuntu-customizer.sh --restore`. El registro de operaciones queda en `~/.local/state/ubuntu-customizer/ubuntu-customizer.log`. La restauración cubre archivos de configuración y ajustes dconf respaldados; no desinstala paquetes, extensiones, temas ni fuentes.
