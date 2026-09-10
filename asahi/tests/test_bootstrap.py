"""Exercise the bootstrap with inert tools; no sudo, DNF, downloads or installs."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[2]


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.home = self.base / "home"
        self.home.mkdir()
        self.log = self.base / "commands"
        self.env = dict(os.environ, HOME=str(self.home), PATH=f"{self.bin}:/usr/bin:/bin",
                        LOG=str(self.log), NVIM_TEST_VERSION="0.12.5", TS_TEST_VERSION="0.26.11")
        self.script = self.base / "bootstrap.sh"
        os_release = self.base / "os-release"
        os_release.write_text('ID=fedora-asahi-remix\nID_LIKE=fedora\nVERSION_ID=44\n')
        text = (PROJECT / "asahi/bootstrap.sh").read_text()
        # Sandbox-only platform fixture: allow tests on non-Fedora/root CI hosts.
        # The actual script's guards remain intact.
        text = text.replace("/etc/os-release", str(os_release))
        text = text.replace('[[ $EUID -ne 0 ]]', '[[ 1 -ne 0 ]]')
        self.script.write_text(text)
        self.packages = self.base / "packages.dnf"
        self.packages.write_text("#@tier 1\n#@repo\nneovim\n#@copr atim/starship\nstarship\n"
                                 "#@tier 2\n#@repo\ntree-sitter-cli\n"
                                 "#@tier 3\n#@repo\nfoot\n#@tier 4\n#@repo\nflatpak\n")
        self.tool("uname", 'echo aarch64')
        self.tool("sudo", 'printf "sudo %s\\n" "$*" >> "$LOG"; exec "$@"')
        self.tool("dnf", 'printf "dnf %s\\n" "$*" >> "$LOG"\n'
                  'if [[ -n ${FAIL_MATCH:-} && "$*" == *"$FAIL_MATCH"* ]]; then echo "MOCK DNF FAILURE" >&2; exit 1; fi')
        self.tool("nvim", 'printf "NVIM v%s\\n" "$NVIM_TEST_VERSION"')
        self.tool("tree-sitter", 'printf "tree-sitter %s\\n" "$TS_TEST_VERSION"')
        self.tool("python3", 'printf "python3 %s\\n" "$*" >> "$LOG"')
        self.tool("cargo", 'printf "cargo %s\\n" "$*" >> "$LOG"')
        self.tool("flatpak", 'printf "flatpak %s\\n" "$*" >> "$LOG"\n'
                  '[[ $1 != info ]] || exit 1\n'
                  'if [[ -n ${FAIL_FLATPAK:-} && "$*" == *"$FAIL_FLATPAK"* ]]; then exit 1; fi')

    def tool(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\nset -euo pipefail\n" + body + "\n")
        path.chmod(0o755)

    def run_script(self, *args, **env):
        return subprocess.run(["bash", str(self.script), *args], capture_output=True,
                              text=True, env=dict(self.env, **env), timeout=15)

    def commands(self):
        return self.log.read_text() if self.log.exists() else ""

    def test_dry_run_only_prints_no_queries_or_writes(self):
        result = self.run_script("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.commands(), "")
        self.assertEqual(list(self.home.iterdir()), [])
        self.assertIn("install neovim", result.stdout)
        self.assertIn("install_asset.py", result.stdout)
        self.assertIn("flatpak install", result.stdout)

    def test_tier_filter_covers_manual_assets_and_flatpaks(self):
        cases = {
            "1": (["install neovim", "install_asset.py lazygit"], ["flatpak", "install_asset.py mise", "cargo install", "jetbrains-mono"]),
            "2": (["install_asset.py mise", "cargo install", "install_asset.py lazydocker"], ["flatpak", "install neovim", "jetbrains-mono"]),
            "3": (["install foot", "install_asset.py jetbrains-mono"], ["flatpak", "install_asset.py mise", "install neovim"]),
            "4": (["flatpak install"], ["install_asset.py", "cargo install", "install neovim"]),
        }
        for tier, (present, absent) in cases.items():
            with self.subTest(tier=tier):
                result = self.run_script("--dry-run", "--tier", tier)
                self.assertEqual(result.returncode, 0, result.stderr)
                for text in present:
                    self.assertIn(text, result.stdout)
                for text in absent:
                    self.assertNotIn(text, result.stdout)

    def test_repeated_tier_flags_select_union(self):
        result = self.run_script("--dry-run", "--tier", "1", "--tier", "2")
        self.assertIn("install neovim", result.stdout)
        self.assertIn("install tree-sitter-cli", result.stdout)
        self.assertNotIn("flatpak install", result.stdout)

    def test_skip_manual_keeps_rpm_neovim(self):
        result = self.run_script("--dry-run", "--skip-manual")
        self.assertIn("install neovim", result.stdout)
        self.assertNotIn("install_asset.py", result.stdout)
        self.assertNotIn("flatpak install", result.stdout)
        self.assertNotIn("cargo install", result.stdout)

    def test_invalid_arguments_do_not_run_any_commands(self):
        for args in [("--tier",), ("--tier", "0"), ("--tier", "5"), ("--tier", "--dry-run"), ("--oops",)]:
            with self.subTest(args=args):
                result = self.run_script(*args)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(self.commands(), "")

    def test_entire_package_file_validated_before_install(self):
        with self.packages.open("a") as out:
            out.write("#@unknown\n")
        result = self.run_script("--skip-manual")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), "")

    def test_no_copr_skips_only_copr_packages(self):
        result = self.run_script("--tier", "1", "--skip-manual", "--no-copr")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("install neovim", self.commands())
        self.assertNotIn("starship", self.commands())

    def test_failed_copr_is_not_used_and_failure_is_nonzero(self):
        result = self.run_script("--tier", "1", "--skip-manual", FAIL_MATCH="copr enable")
        self.assertEqual(result.returncode, 1)
        self.assertIn("fedora-44-aarch64", self.commands())
        self.assertNotIn("install starship", self.commands())
        self.assertIn("MOCK DNF FAILURE", result.stderr)

    def test_failed_package_is_reported_with_nonzero_exit(self):
        result = self.run_script("--tier", "1", "--skip-manual", "--no-copr", FAIL_MATCH="install neovim")
        self.assertEqual(result.returncode, 1)
        self.assertIn("MOCK DNF FAILURE", result.stderr)
        self.assertIn("ÉCHEC", result.stdout)

    def test_old_neovim_09_is_not_mistaken_for_newer_version(self):
        result = self.run_script("--tier", "1", "--skip-manual", "--no-copr", NVIM_TEST_VERSION="0.9.5")
        self.assertEqual(result.returncode, 1)
        self.assertIn("upgrade neovim", self.commands())
        self.assertIn("nvim >= 0.12", result.stderr)

    def test_neovim_1x_passes_version_check(self):
        result = self.run_script("--tier", "1", "--skip-manual", "--no-copr", NVIM_TEST_VERSION="1.0.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("upgrade neovim", self.commands())

    def test_tree_sitter_patch_minimum_is_enforced(self):
        result = self.run_script("--tier", "2", "--skip-manual", TS_TEST_VERSION="0.26.0")
        self.assertEqual(result.returncode, 1)
        self.assertIn("0.26.1", result.stderr)

    def test_flatpak_remote_failure_is_not_misreported_as_success(self):
        result = self.run_script("--tier", "4", FAIL_FLATPAK="remote-add")
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("flatpak install", self.commands())

    def test_flatpak_app_failure_is_counted(self):
        result = self.run_script("--tier", "4", FAIL_FLATPAK="org.signal.Signal")
        self.assertEqual(result.returncode, 1)
        self.assertIn("org.signal.Signal", result.stdout)
        self.assertIn("--user --arch=aarch64", self.commands())

    def test_manual_download_failure_is_counted(self):
        self.tool("python3", 'echo "MOCK ASSET FAILURE" >&2; exit 1')
        result = self.run_script("--tier", "3")
        self.assertEqual(result.returncode, 1)
        self.assertIn("asset jetbrains-mono", result.stdout)


if __name__ == "__main__":
    unittest.main()
