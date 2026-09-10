import hashlib
import io
import json
from pathlib import Path
import shutil
import sys
import tarfile
import tempfile
import unittest
from unittest import mock

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT / "asahi/lib"))
import install_asset as assets


class AssetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.archive = self.base / "test.tar.gz"
        self.home = self.base / "home"
        self.home.mkdir()
        self.asset = {"version": "1.2.3", "url": "https://example.invalid/release.tar.gz",
                      "sha256": "0" * 64, "binaries": {"tool/bin/tool": "tool"}}

    def make_archive(self, members):
        with tarfile.open(self.archive, "w:gz") as archive:
            for name, content in members:
                info = tarfile.TarInfo(name)
                if isinstance(content, tuple):
                    info.type = tarfile.SYMTYPE
                    info.linkname = content[0]
                    archive.addfile(info)
                else:
                    raw = content.encode()
                    info.size = len(raw)
                    archive.addfile(info, io.BytesIO(raw))
        self.asset["sha256"] = hashlib.sha256(self.archive.read_bytes()).hexdigest()

    def unpack(self):
        out = self.base / "unpacked"
        out.mkdir(exist_ok=True)
        return assets.unpack(self.asset, self.archive, out)

    def install(self, **kwargs):
        def download(_asset, dst):
            shutil.copyfile(self.archive, dst)
        with mock.patch.object(assets, "download", side_effect=download), mock.patch.object(assets.subprocess, "run"):
            assets.install(self.asset, self.home, **kwargs)

    def test_pinned_asset_metadata_has_complete_https_sha256_records(self):
        data = json.loads((PROJECT / "asahi/assets.json").read_text())
        for name, entry in data.items():
            with self.subTest(name=name):
                self.assertTrue(entry["url"].startswith("https://github.com/"))
                self.assertRegex(entry["sha256"], r"^[0-9a-f]{64}$")
                self.assertTrue(entry.get("binaries") or entry.get("fonts"))

    def test_checksum_verification_accepts_only_expected_content(self):
        self.make_archive([("tool/bin/tool", "binary")])
        raw = self.archive.read_bytes()
        def response(_request, **_kw):
            result = io.BytesIO(raw)
            result.url = self.asset["url"]
            return result
        with mock.patch.object(assets.urllib.request, "urlopen", side_effect=response):
            assets.download(self.asset, self.base / "downloaded")
            self.asset["sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "SHA-256 incorrect"):
                assets.download(self.asset, self.base / "bad")

    def test_download_failure_leaves_existing_binary_untouched(self):
        destination = self.home / ".local/bin/tool"
        destination.parent.mkdir(parents=True)
        destination.write_text("old")
        with mock.patch.object(assets, "download", side_effect=OSError("network failed")):
            with self.assertRaises(OSError):
                assets.install(self.asset, self.home)
        self.assertEqual(destination.read_text(), "old")
        self.assertFalse(list(self.home.rglob("*.bak.*")))

    def test_invalid_archive_leaves_existing_binary_untouched(self):
        destination = self.home / ".local/bin/tool"
        destination.parent.mkdir(parents=True)
        destination.write_text("old")
        self.archive.write_bytes(b"not a tarball")
        with self.assertRaises(tarfile.TarError):
            self.install()
        self.assertEqual(destination.read_text(), "old")

    def test_missing_binary_is_rejected(self):
        self.make_archive([("wrong-name", "binary")])
        with self.assertRaisesRegex(ValueError, "manque"):
            self.unpack()

    def test_archive_traversal_symlinks_and_duplicates_rejected(self):
        cases = [[("../escape", "bad")], [("/escape", "bad")],
                 [("tool/bin/tool", ("/etc/passwd",))],
                 [("tool/bin/tool", "one"), ("tool/bin/tool", "two")]]
        for members in cases:
            with self.subTest(members=members):
                self.make_archive(members)
                with self.assertRaises(ValueError):
                    self.unpack()

    def test_install_backs_up_old_binary_and_is_idempotent(self):
        self.make_archive([("tool/bin/tool", "new binary")])
        dst = self.home / ".local/bin/tool"
        dst.parent.mkdir(parents=True)
        dst.write_text("old binary")
        self.install()
        self.assertEqual(dst.read_text(), "new binary")
        self.assertEqual(dst.stat().st_mode & 0o777, 0o755)
        backups = list(dst.parent.glob("tool.bak.*"))
        self.assertEqual(backups[0].read_text(), "old binary")
        self.install()
        self.assertEqual(list(dst.parent.glob("tool.bak.*")), backups)

    def test_verify_only_does_not_create_any_installation_paths(self):
        self.make_archive([("tool/bin/tool", "binary")])
        self.install(verify_only=True)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_font_receipt_detects_damaged_or_missing_files(self):
        self.asset.pop("binaries")
        self.asset["fonts"] = "TestFont"
        self.make_archive([("Font.ttf", "font"), ("LICENSE.txt", "license")])
        self.install()
        dst = self.home / ".local/share/fonts/TestFont"
        self.assertTrue(assets.font_receipt_valid(dst, self.asset))
        (dst / "Font.ttf").write_text("damaged")
        self.assertFalse(assets.font_receipt_valid(dst, self.asset))
        self.install()
        self.assertEqual((dst / "Font.ttf").read_text(), "font")

    def test_multiple_binaries_rollback_together_on_publication_failure(self):
        self.asset["binaries"] = {"tool": "tool", "other": "other"}
        self.make_archive([("tool", "new"), ("other", "second")])
        dst = self.home / ".local/bin/tool"
        dst.parent.mkdir(parents=True)
        dst.write_text("old")
        real_publish = assets.publish
        def publish(src, target):
            if target.name == "other":
                raise OSError("rename failed")
            return real_publish(src, target)
        with mock.patch.object(assets, "publish", side_effect=publish):
            with self.assertRaises(OSError):
                self.install()
        self.assertEqual(dst.read_text(), "old")
        self.assertFalse((dst.parent / "other").exists())


if __name__ == "__main__":
    unittest.main()
