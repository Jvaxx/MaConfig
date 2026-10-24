"""Isolated HOME/repository; never reload the real desktop."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.repo = root / 'repo' / 'm3pro'
        self.repo.mkdir(parents=True)
        self.home = root / 'home'
        self.home.mkdir()
        # Fake Omarchy tree: the audit must never read the installed defaults.
        self.omarchy = root / 'omarchy'
        (self.omarchy / 'config').mkdir(parents=True)
        self.env = dict(os.environ, HOME=str(self.home), OMARCHY_PATH=str(self.omarchy))
        for name in ('lib.sh', 'restore.sh', 'sync.sh'):
            shutil.copy2(SOURCE / name, self.repo / name)
        (self.repo / 'MANIFEST').write_text('.config/app\nshared:.config/shared\ncopy:.config/state\n')
        for path, text in (
            (self.repo / 'home/.config/app', 'repository'),
            (self.repo.parent / 'shared/home/.config/shared/item', 'shared'),
            (self.repo / 'home/.config/state', 'saved'),
            (self.home / '.config/app', 'local'),
            (self.home / '.config/state', 'live'),
        ):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)

    def run_script(self, name, *args, ok=True):
        result = subprocess.run(['bash', str(self.repo / name), *args],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def restore(self):
        self.run_script('restore.sh', '--yes', '--no-reload')

    def test_restore_and_idempotence(self):
        self.restore()
        app = self.home / '.config/app'
        self.assertTrue(app.is_symlink())
        self.assertEqual(app.read_text(), 'repository')
        self.assertEqual(next(app.parent.glob('app.bak.*')).read_text(), 'local')
        self.assertTrue((self.home / '.config/shared').is_symlink())
        self.assertFalse((self.home / '.config/state').is_symlink())
        backups = list(self.home.rglob('*.bak.*'))
        self.restore()
        self.assertEqual(backups, list(self.home.rglob('*.bak.*')))
        app.write_text('edited')
        self.assertEqual((self.repo / 'home/.config/app').read_text(), 'edited')
        self.run_script('sync.sh', '--dry-run')

    def test_dry_run(self):
        self.run_script('restore.sh', '--dry-run')
        self.assertFalse((self.home / '.config/app').is_symlink())
        self.assertFalse(list(self.home.rglob('*.bak.*')))
        self.assertFalse((self.home / '.config/shared').exists())

    def test_sync_refuses_unlinked_before_writing(self):
        self.run_script('sync.sh', ok=False)
        self.assertEqual((self.repo / 'home/.config/state').read_text(), 'saved')
        self.assertFalse((self.repo / 'STATE').exists())

    def test_missing_source_preflight(self):
        (self.repo / 'home/.config/state').unlink()
        self.run_script('restore.sh', '--yes', '--no-reload', ok=False)
        self.assertEqual((self.home / '.config/app').read_text(), 'local')
        self.assertFalse(list(self.home.rglob('*.bak.*')))

    def test_broken_link_backed_up(self):
        app = self.home / '.config/app'
        app.unlink()
        app.symlink_to('/nonexistent-maconfig-test')
        self.restore()
        self.assertEqual(os.readlink(next(app.parent.glob('app.bak.*'))),
                         '/nonexistent-maconfig-test')
        self.assertEqual(app.read_text(), 'repository')

    def test_copy_sync_and_exports(self):
        self.restore()
        (self.home / '.config/state').write_text('new state')
        # Stubs prevent querying the installed system; plugin directory is empty.
        tools = self.home / 'bin'
        tools.mkdir()
        for name, output in [('pacman', 'test-package'), ('omarchy', 'test-version')]:
            path = tools / name
            path.write_text('#!/bin/sh\nprintf "%s\\n" ' + output + '\n')
            path.chmod(0o755)
        self.env['PATH'] = str(tools) + ':' + os.environ['PATH']
        self.run_script('sync.sh', '--dry-run')
        self.assertEqual((self.repo / 'home/.config/state').read_text(), 'saved')
        self.assertFalse((self.repo / 'STATE').exists())
        self.run_script('sync.sh')
        self.assertEqual((self.repo / 'home/.config/state').read_text(), 'new state')
        self.assertIn('test-package', (self.repo / 'packages.txt').read_text())
        self.assertIn('test-version', (self.repo / 'STATE').read_text())

    def test_plugin_backup_outside_discovery(self):
        for parent, marker in (('.config/omarchy/plugins', 'manifest.json'),
                               ('.claude/skills', 'SKILL.md')):
            with self.subTest(parent=parent):
                rel = parent + '/custom'
                (self.repo / 'MANIFEST').write_text(rel + '\n')
                for base in (self.home, self.repo / 'home'):
                    plugin = base / rel
                    plugin.mkdir(parents=True)
                    (plugin / marker).write_text('{}')
                self.restore()
                self.assertTrue((self.home / rel).is_symlink())
                self.assertEqual(len(list((self.home / parent).iterdir())), 1)
                self.assertEqual(len(list((self.home / '.local/state/maconfig/backups').rglob(marker))), 1)

    def test_restore_keeps_newer_copy(self):
        state, saved = self.home / '.config/state', self.repo / 'home/.config/state'
        os.utime(saved, (1_000_000_000, 1_000_000_000))
        self.restore()
        self.assertEqual(state.read_text(), 'live')
        self.assertFalse(list(state.parent.glob('state.bak.*')))
        os.utime(state, (900_000_000, 900_000_000))
        self.restore()
        self.assertEqual(state.read_text(), 'saved')
        self.assertEqual(next(state.parent.glob('state.bak.*')).read_text(), 'live')

    def test_audit_reports_untracked(self):
        self.restore()
        default = self.omarchy / 'config/tool/conf'
        default.parent.mkdir(parents=True)
        default.write_text('default')
        for rel, text in (('.config/tool/conf', 'custom'), ('.local/bin/new-script', 'x'),
                          ('.local/bin/ignored-script', 'x'), ('.local/bin/old.bak.1', 'x')):
            path = self.home / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        (self.repo / 'UNTRACKED').write_text('# comment\n.local/bin/ignored-*\n')
        out = self.run_script('sync.sh', '--dry-run').stdout
        self.assertIn('.config/tool/conf (diffère du défaut Omarchy)', out)
        self.assertIn('.local/bin/new-script', out)
        self.assertNotIn('ignored-script', out)
        self.assertNotIn('old.bak', out)
        # Tracked paths and stock-identical defaults are not reported.
        (self.home / '.config/tool/conf').write_text('default')
        out = self.run_script('sync.sh', '--dry-run').stdout
        self.assertNotIn('tool/conf', out)
        self.assertNotIn('.config/app', out)

    def test_plugin_without_origin(self):
        self.restore()
        plugin = self.home / '.config/omarchy/plugins/local'
        plugin.mkdir(parents=True)
        subprocess.run(['git', 'init', '-q', str(plugin)], check=True)
        result = self.run_script('sync.sh')
        self.assertIn('sans remote origin', result.stderr)
        self.assertEqual((self.repo / 'external-plugins.txt').read_text(), '')

    def test_invalid_path_and_option(self):
        self.run_script('restore.sh', '--invalid', ok=False)
        (self.repo / 'MANIFEST').write_text('../escape\n')
        self.run_script('restore.sh', '--yes', '--no-reload', ok=False)
        self.assertFalse(list(self.home.rglob('*.bak.*')))


if __name__ == '__main__':
    unittest.main()
