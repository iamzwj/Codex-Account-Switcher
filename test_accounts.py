import argparse
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

accounts = runpy.run_path(str(Path(__file__).with_name('codex-accounts')))
scope = accounts['open_profile'].__globals__


class AccountsTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def test_profile_names(self):
        self.assertEqual(accounts['profile_name']('work-2'), 'work-2')
        for invalid in ('../work', '/work', 'Work', 'a b', 'a' * 41):
            with self.subTest(invalid=invalid):
                with self.assertRaises(argparse.ArgumentTypeError):
                    accounts['profile_name'](invalid)

    def test_separate_private_directories_and_config_preserved(self):
        home, desktop = accounts['prepare'](self.root, 'personal')
        work_home, work_desktop = accounts['prepare'](self.root, 'work')
        self.assertEqual(len({home, desktop, work_home, work_desktop}), 4)
        for directory in (home, desktop, work_home, work_desktop):
            self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
        config = home / 'config.toml'
        self.assertIn('"keyring"', config.read_text())
        config.write_text('# custom\n')
        accounts['prepare'](self.root, 'personal')
        self.assertEqual(config.read_text(), '# custom\n')

    def test_symlink_profile_rejected(self):
        target = accounts['private_dir'](self.root / 'target')
        (self.root / 'work').symlink_to(target)
        with self.assertRaises(ValueError):
            accounts['prepare'](self.root, 'work')

    def test_switch_requires_quit(self):
        with patch.dict(scope, {'check_app': lambda app: None, 'desktop_running': lambda: True}):
            with self.assertRaisesRegex(ValueError, '⌘Q'):
                accounts['open_profile'](Path('/App.app'), self.root, 'work')
        self.assertFalse((self.root / 'work').exists())

    def test_open_passes_both_profile_directories(self):
        app = Path('/App.app')
        with patch.dict(scope, {'check_app': lambda app: None, 'desktop_running': lambda: False}):
            with patch.object(accounts['subprocess'], 'run') as launch:
                accounts['open_profile'](app, self.root, 'work')
        profile = self.root / 'work'
        launch.assert_called_once_with([
            '/usr/bin/open', '-n',
            '--env', f'CODEX_HOME={profile / "codex"}',
            '--env', f'CODEX_ELECTRON_USER_DATA_PATH={profile / "desktop"}',
            str(app), '--args', f'--user-data-dir={profile / "desktop"}',
        ], check=True, timeout=30)


if __name__ == '__main__':
    unittest.main()
