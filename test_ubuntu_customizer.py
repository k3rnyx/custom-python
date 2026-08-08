from pathlib import Path
import unittest


SOURCE = Path(__file__).parent / "app" / "ubuntu_customizer.py"


class GnomeTerminalProfilePathTest(unittest.TestCase):
    def test_uses_relocatable_profile_segment(self):
        source = SOURCE.read_text(encoding="utf-8")

        self.assertIn('perfil = f"{base}:{TERMINAL_PROFILE_UUID}/"', source)
        self.assertNotIn('perfil = f"{base}{TERMINAL_PROFILE_UUID}/"', source)


if __name__ == "__main__":
    unittest.main()
