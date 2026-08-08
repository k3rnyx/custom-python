from pathlib import Path
import unittest


SOURCE = Path(__file__).parent / "app" / "ubuntu_customizer.py"


class PtyxisProfileTest(unittest.TestCase):
    def test_configures_ptyxis_default_profile_palette(self):
        source = SOURCE.read_text(encoding="utf-8")

        self.assertIn('f"{base}Profiles/{perfil}/palette"', source)
        self.assertIn('"\'Tokyo Night Storm\'"', source)
        self.assertIn('("font-name", "\'JetBrainsMono Nerd Font Mono 11\'")', source)
        self.assertIn('("cursor-shape", "\'block\'")', source)
        self.assertIn('("cursor-blink-mode", "\'off\'")', source)
        self.assertIn("eliminar_perfil_gnome_terminal(dry_run=dry_run)", source)
        self.assertIn("_sincronizar_coleccion_wallpapers(REPOSITORIO_WALLPAPERS_TOKYONIGHT, destino)", source)


if __name__ == "__main__":
    unittest.main()
