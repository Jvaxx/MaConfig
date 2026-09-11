"""Offline regression tests: every write is confined to a temporary directory."""
import argparse
from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT / "asahi/lib"))
import config_io as cio
import storage


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / "repo"
        self.home = self.base / "home"
        self.home.mkdir()
        self.manifest = self.root / "asahi/MANIFEST"
        write(self.manifest, ".bashrc\nshared:.config/nvim\n")
        write(self.root / "asahi/home/.bashrc", "new rc\n")
        write(self.root / "shared/home/.config/nvim/init.lua", "new vim\n")

    def transfer(self, action="restore", **kw):
        args = argparse.Namespace(action=action, dry_run=False, yes=True,
                                  link=False, commit=False)
        for key, value in kw.items():
            setattr(args, key, value)
        with redirect_stdout(io.StringIO()), mock.patch.object(cio, "metadata", return_value={"STATE": "state\n"}):
            cio.transfer(args, self.root, self.home)

    def test_copy_backup_and_idempotent_rerun(self):
        write(self.home / ".bashrc", "old rc\n")
        self.transfer()
        self.assertEqual((self.home / ".bashrc").read_text(), "new rc\n")
        backups = list(self.home.glob(".bashrc.bak.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "old rc\n")
        self.transfer()
        self.assertEqual(list(self.home.glob(".bashrc.bak.*")), backups)

    def test_link_and_copy_mode_preserves_existing_link(self):
        self.transfer(link=True)
        target = self.home / ".config/nvim"
        self.assertTrue(target.is_symlink())
        self.transfer()
        self.transfer("sync")
        self.assertTrue(target.is_symlink())
        self.assertEqual((target / "init.lua").read_text(), "new vim\n")
        self.assertEqual(list(self.home.rglob("*.bak.*")), [])

    def test_broken_destination_symlink_is_backed_up_not_followed(self):
        (self.home / ".bashrc").symlink_to(self.base / "absent")
        self.transfer()
        self.assertEqual((self.home / ".bashrc").read_text(), "new rc\n")
        self.assertTrue(next(self.home.glob(".bashrc.bak.*")).is_symlink())
        self.assertFalse((self.base / "absent").exists())

    def test_dry_run_does_not_create_destinations(self):
        self.transfer(dry_run=True)
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertFalse((self.root / "asahi/.operation.lock").exists())

    def test_missing_source_preflight_changes_nothing(self):
        write(self.home / ".bashrc", "old")
        (self.root / "shared/home/.config/nvim/init.lua").unlink()
        (self.root / "shared/home/.config/nvim").rmdir()
        with self.assertRaisesRegex(ValueError, "Source absente"):
            self.transfer()
        self.assertEqual((self.home / ".bashrc").read_text(), "old")
        self.assertEqual(list(self.home.glob("*.bak.*")), [])

    def test_failed_copy_preserves_all_old_destinations(self):
        write(self.home / ".bashrc", "old")
        write(self.home / ".config/nvim/init.lua", "old vim")
        original = cio.copy_file
        def copy(src, dst):
            if Path(src).name == "init.lua":
                raise OSError("simulated disk full")
            return original(src, dst)
        with mock.patch.object(cio, "copy_file", side_effect=copy):
            with self.assertRaisesRegex(OSError, "disk full"):
                self.transfer()
        self.assertEqual((self.home / ".bashrc").read_text(), "old")
        self.assertEqual((self.home / ".config/nvim/init.lua").read_text(), "old vim")
        self.assertFalse(list(self.home.rglob(".maconfig-stage-*")))

    def test_later_publish_failure_rolls_back_earlier_publication(self):
        write(self.home / ".bashrc", "old")
        original = cio.publish
        def publish(src, dst):
            if dst.name == "nvim":
                raise OSError("rename failed")
            return original(src, dst)
        with mock.patch.object(cio, "publish", side_effect=publish):
            with self.assertRaises(OSError):
                self.transfer()
        self.assertEqual((self.home / ".bashrc").read_text(), "old")
        self.assertFalse((self.home / ".config/nvim").exists())

    def test_publish_primitive_restores_after_second_rename_fails(self):
        dst, staged = self.base / "destination", self.base / "new"
        write(dst, "old")
        write(staged, "new")
        original = Path.replace
        def replace(path, target):
            if path == staged:
                raise OSError("rename failure")
            return original(path, target)
        with mock.patch.object(Path, "replace", replace):
            with self.assertRaises(OSError):
                storage.publish(staged, dst)
        self.assertEqual(dst.read_text(), "old")
        self.assertEqual(staged.read_text(), "new")

    def test_destination_parent_cannot_escape_home(self):
        outside = self.base / "outside"
        outside.mkdir()
        (self.home / ".config").symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "Parent redirigé"):
            self.transfer()
        self.assertEqual(list(outside.iterdir()), [])
        self.assertFalse((self.home / ".bashrc").exists())

    def test_nested_external_symlink_rejected_before_copy(self):
        (self.root / "shared/home/.config/nvim/escape").symlink_to("/etc/passwd")
        with self.assertRaisesRegex(ValueError, "Lien non portable"):
            self.transfer()
        self.assertEqual(list(self.home.iterdir()), [])

    def test_internal_relative_symlink_preserved(self):
        (self.root / "shared/home/.config/nvim/link.lua").symlink_to("init.lua")
        self.transfer()
        self.assertEqual(os.readlink(self.home / ".config/nvim/link.lua"), "init.lua")

    def test_sync_excludes_metadata_and_retains_previous_backup(self):
        self.transfer()
        write(self.home / ".config/nvim/init.lua", "changed")
        write(self.home / ".config/nvim/.git/config", "secret")
        write(self.home / ".config/nvim/private.bak.1", "old secret")
        self.transfer("sync")
        dst = self.root / "shared/home/.config/nvim"
        self.assertEqual((dst / "init.lua").read_text(), "changed")
        self.assertFalse((dst / ".git").exists())
        self.assertFalse((dst / "private.bak.1").exists())
        self.assertEqual((next(dst.parent.glob("nvim.bak.*")) / "init.lua").read_text(), "new vim\n")

    def test_sync_reads_external_top_level_source_as_content(self):
        self.transfer()
        (self.home / ".bashrc").unlink()
        write(self.base / "other-rc", "external content")
        (self.home / ".bashrc").symlink_to(self.base / "other-rc")
        self.transfer("sync")
        dst = self.root / "asahi/home/.bashrc"
        self.assertFalse(dst.is_symlink())
        self.assertEqual(dst.read_text(), "external content")

    def test_sync_missing_source_leaves_repository_unchanged(self):
        with self.assertRaisesRegex(ValueError, "Source absente"):
            self.transfer("sync")
        self.assertEqual((self.root / "asahi/home/.bashrc").read_text(), "new rc\n")
        self.assertFalse((self.root / "asahi/STATE").exists())

    def test_manifest_rejects_unsafe_duplicate_and_overlapping_paths(self):
        for text in ["../oops", "/tmp/oops", "a/../b", "a//b", "a/./b", ".git/config",
                     "a\nshared:a", "a\na/b", "a/b\na", "shared:", "", "a:b"]:
            with self.subTest(text=text):
                self.manifest.write_text(text)
                with self.assertRaises(ValueError):
                    cio.manifest(self.manifest, self.root)

    def test_manifest_supports_spaces_comments_and_no_final_newline(self):
        self.manifest.write_text(" # ignored\n shared:.config/a space # comment")
        entries = cio.manifest(self.manifest, self.root)
        self.assertEqual(entries[0].relative, ".config/a space")

    def test_metadata_uses_userinstalled_query_newlines_and_deduplication(self):
        with mock.patch.object(cio.shutil, "which", side_effect=lambda c: "/dnf" if c == "dnf" else None):
            with mock.patch.object(cio, "execute", return_value=subprocess.CompletedProcess([], 0, "z\na\na\n")) as run:
                data = cio.metadata()
        command = run.call_args.args[0]
        self.assertIn("--cacheonly", command)
        self.assertIn("--userinstalled", command)
        self.assertNotIn("--installed", command)
        self.assertEqual(command[-1], "%{name}\n")
        self.assertTrue(data["packages.installed.txt"].endswith("a\nz\n"))

    def test_failed_metadata_query_precedes_publication(self):
        self.transfer()
        write(self.home / ".bashrc", "changed")
        args = argparse.Namespace(action="sync", dry_run=False, yes=False, link=False, commit=False)
        with mock.patch.object(cio, "metadata", side_effect=OSError("dnf failed")):
            with self.assertRaisesRegex(OSError, "dnf failed"):
                cio.transfer(args, self.root, self.home)
        self.assertEqual((self.root / "asahi/home/.bashrc").read_text(), "new rc\n")

    def test_lock_refuses_concurrent_operation(self):
        with cio.operation_lock(self.root):
            with self.assertRaisesRegex(RuntimeError, "en cours"):
                with cio.operation_lock(self.root):
                    self.fail("second operation entered")

    def init_git(self):
        self.git("init", "-q")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        shutil.copyfile(PROJECT / ".gitignore", self.root / ".gitignore")
        write(self.root / "quattro/unrelated", "old")
        write(self.root / "asahi/bootstrap.sh", "old")
        self.git("add", ".")
        self.git("commit", "-qm", "initial")

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True, text=True).stdout

    def test_commit_only_stages_manifest_and_metadata(self):
        self.init_git()
        self.transfer()
        write(self.home / ".bashrc", "updated")
        write(self.root / "quattro/unrelated", "uncommitted")
        write(self.root / "asahi/bootstrap.sh", "uncommitted")
        self.transfer("sync", commit=True)
        files = self.git("diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").splitlines()
        self.assertEqual(set(files), {"asahi/home/.bashrc", "asahi/STATE"})
        status = self.git("status", "--porcelain")
        self.assertIn(" M quattro/unrelated", status)
        self.assertIn(" M asahi/bootstrap.sh", status)
        self.assertNotIn(".bak.", status)

    def test_commit_refuses_existing_index_before_writing(self):
        self.init_git()
        self.transfer()
        write(self.home / ".bashrc", "updated")
        write(self.root / "quattro/unrelated", "staged")
        self.git("add", "quattro/unrelated")
        with self.assertRaisesRegex(ValueError, "Index Git non vide"):
            self.transfer("sync", commit=True)
        self.assertEqual((self.root / "asahi/home/.bashrc").read_text(), "new rc\n")
        self.assertIn("quattro/unrelated", self.git("diff", "--cached", "--name-only"))

    def test_wrapper_dry_run_has_no_bytecode_or_lock_side_effects(self):
        shutil.copytree(PROJECT / "asahi/lib", self.root / "asahi/lib", ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copyfile(PROJECT / "asahi/restore.sh", self.root / "asahi/restore.sh")
        before = set(self.root.rglob("*"))
        env = dict(os.environ, HOME=str(self.home))
        result = subprocess.run(["bash", str(self.root / "asahi/restore.sh"), "--dry-run"],
                                env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(self.root.rglob("*")), before)
        self.assertEqual(list(self.home.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
