"""Tests isolés : pas d'accès au vrai HOME, à Homebrew ou au réseau."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

MACOS = Path(__file__).resolve().parents[1]


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="maconfig-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.repo = self.base / "repo with spaces"
        self.mac = self.repo / "macos"
        self.mac.mkdir(parents=True)
        for script in ("lib.sh", "sync.sh", "restore.sh", "defaults.sh"):
            shutil.copy2(MACOS / script, self.mac / script)
        self.home = self.base / "home"
        self.home.mkdir()
        self.bin = self.base / "bin"
        self.bin.mkdir()
        brew = self.bin / "brew"
        brew.write_text('#!/bin/bash\nexit 0\n')
        brew.chmod(0o755)
        # A minimal brew mock writing only to the requested dump file.
        brew.write_text('''#!/bin/bash
for arg in "$@"; do
  case "$arg" in --file=*) printf 'brew "bob"\\n' > "${arg#--file=}";; esac
done
''')
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=f"{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin")
        (self.mac / "MANIFEST").write_text(
            "# test\n.zshrc\nshared:.config/nvim\nLibrary/Application Support/test/config\n")
        self.put(self.mac / "home/.zshrc", "remote shell\n")
        self.put(self.repo / "shared/home/.config/nvim/init.lua", "remote nvim\n")
        self.put(self.mac / "home/Library/Application Support/test/config", "space\n")

    def put(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def run_script(self, script, *args, ok=True):
        result = subprocess.run(["/bin/bash", str(self.mac / script), *args],
                                env=self.env, text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_dry_runs_do_not_write(self):
        before = sorted(str(p) for p in self.base.rglob("*"))
        self.run_script("restore.sh", "--dry-run")
        self.run_script("sync.sh", "--dry-run", "--commit")
        self.run_script("defaults.sh", "--dry-run")
        self.assertEqual(before, sorted(str(p) for p in self.base.rglob("*")))

    def test_restore_remote_wins_with_backup(self):
        self.put(self.home / ".zshrc", "local\n")
        self.put(self.home / ".config/nvim/stale.lua", "old\n")
        self.run_script("restore.sh", "--yes")
        self.assertEqual((self.home / ".zshrc").read_text(), "remote shell\n")
        self.assertEqual(next(self.home.glob(".zshrc.bak.*")).read_text(), "local\n")
        self.assertFalse((self.home / ".config/nvim/stale.lua").exists())
        self.assertTrue(next((self.home / ".config").glob("nvim.bak.*"))
                        .joinpath("stale.lua").exists())
        self.assertEqual((self.home / "Library/Application Support/test/config")
                         .read_text(), "space\n")

    def test_sync_shared_exclusions_and_deletion(self):
        self.run_script("restore.sh", "--yes")
        self.put(self.home / ".config/nvim/init.lua", "edited\n")
        self.put(self.home / ".config/nvim/.git/config", "private\n")
        self.put(self.home / ".config/nvim/.DS_Store", "cache\n")
        self.put(self.home / ".config/nvim/init.lua.bak.123", "old\n")
        self.put(self.repo / "shared/home/.config/nvim/stale.lua", "stale\n")
        self.run_script("sync.sh")
        shared = self.repo / "shared/home/.config/nvim"
        self.assertEqual(sorted(p.name for p in shared.iterdir()), ["init.lua"])
        self.assertEqual((shared / "init.lua").read_text(), "edited\n")
        self.assertTrue((self.mac / "Brewfile").exists())
        self.assertTrue((self.mac / "STATE").exists())

    def test_link_into_repo_survives_both_directions(self):
        target = self.repo / "shared/home/.config/nvim"
        (self.home / ".config").mkdir()
        (self.home / ".config/nvim").symlink_to(target, target_is_directory=True)
        self.run_script("restore.sh", "--yes")
        self.run_script("sync.sh")
        self.assertTrue((self.home / ".config/nvim").is_symlink())
        self.assertEqual((target / "init.lua").read_text(), "remote nvim\n")

    def test_restore_replaces_external_and_broken_links_safely(self):
        target = self.base / "external"
        target.write_text("untouched\n")
        (self.home / ".zshrc").symlink_to(target)
        (self.home / ".config").mkdir()
        (self.home / ".config/nvim").symlink_to(self.base / "missing")
        self.run_script("restore.sh", "--yes")
        self.assertEqual(target.read_text(), "untouched\n")
        self.assertTrue(next(self.home.glob(".zshrc.bak.*")).is_symlink())
        self.assertTrue(next((self.home / ".config").glob("nvim.bak.*")).is_symlink())

    def test_missing_source_preflight(self):
        (self.mac / "home/.zshrc").unlink()
        self.run_script("restore.sh", "--yes", ok=False)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_missing_local_preserves_backup(self):
        self.run_script("sync.sh")
        self.assertEqual((self.mac / "home/.zshrc").read_text(), "remote shell\n")

    def test_invalid_paths_and_options(self):
        for entry in ("../outside", "shared:/absolute", ".config/../../outside"):
            (self.mac / "MANIFEST").write_text(entry + "\n")
            self.run_script("restore.sh", "--yes", ok=False)
            self.run_script("sync.sh", ok=False)
        self.run_script("restore.sh", "--typo", ok=False)
        self.run_script("sync.sh", "--typo", ok=False)

    def test_failed_copy_preserves_existing_destination(self):
        self.run_script("restore.sh", "--yes")
        self.put(self.home / ".config/nvim/init.lua", "local edit\n")
        rsync = self.bin / "rsync"
        rsync.write_text("#!/bin/bash\nexit 1\n")
        rsync.chmod(0o755)
        self.run_script("sync.sh", ok=False)
        self.assertEqual((self.repo / "shared/home/.config/nvim/init.lua")
                         .read_text(), "remote nvim\n")
        self.assertEqual(list(self.repo.rglob(".maconfig-stage-*")), [])

    def test_commit_does_not_include_other_staged_files(self):
        def git(*args):
            return subprocess.run(
                ["git", "-C", str(self.repo), *args], env=self.env,
                text=True, capture_output=True, check=True).stdout
        git("init")
        git("config", "user.name", "Test")
        git("config", "user.email", "test@example.invalid")
        git("config", "commit.gpgsign", "false")
        git("add", ".")
        git("commit", "-m", "initial")
        self.put(self.repo / "unrelated.txt", "leave staged\n")
        git("add", "unrelated.txt")
        self.run_script("restore.sh", "--yes")
        self.run_script("sync.sh", "--commit")
        self.assertEqual(git("diff", "--cached", "--name-only").strip(), "unrelated.txt")
        self.assertNotIn("unrelated.txt", git("ls-tree", "--name-only", "HEAD"))
        self.assertIn("macos: sync config", git("log", "-1", "--format=%s"))

    def test_executable_modes_preserved(self):
        (self.mac / "home/.zshrc").chmod(0o755)
        self.run_script("restore.sh", "--yes")
        self.assertTrue(os.access(self.home / ".zshrc", os.X_OK))


if __name__ == "__main__":
    unittest.main()
