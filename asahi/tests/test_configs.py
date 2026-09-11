import ctypes
import ctypes.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[2]


class ShellTests(unittest.TestCase):
    def test_bash_syntax(self):
        paths = list((PROJECT / "asahi").glob("*.sh"))
        paths += list((PROJECT / "asahi/home").glob(".bash*"))
        paths += [p for p in (PROJECT / "asahi/home/.local/bin").glob("*") if p.is_file()]
        paths += list((PROJECT / "shared/home/.config/shell").glob("*.bash"))
        for path in paths:
            with self.subTest(path=path):
                subprocess.run(["bash", "-n", str(path)], check=True)

    def test_python_syntax_without_writing_bytecode(self):
        for path in (PROJECT / "asahi").rglob("*.py"):
            with self.subTest(path=path):
                compile(path.read_text(), str(path), "exec")

    @unittest.skipUnless(shutil.which("foot"), "foot not installed")
    def test_foot_config_validates_without_opening_window(self):
        result = subprocess.run(["foot", "-S", "--check-config", "--config",
                                 str(PROJECT / "asahi/home/.config/foot/foot.ini")],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("deprecated", result.stderr)

    def test_kde_shortcuts_script_sends_expected_qt_keycodes(self):
        script = PROJECT / "asahi/home/.local/bin/kde-omarchy-keys"
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / "bin").mkdir()
            log = home / "calls.txt"
            (home / "bin/busctl").write_text(
                '#!/bin/bash\n'
                'printf "%s\\n" "$*" >> "$CALL_LOG"\n'
                'case "$*" in *shortcutKeys*) echo "a(ai) 0";; esac\n'
                'exit 0\n')
            for name in ("kwriteconfig6", "xdg-mime"):
                (home / "bin" / name).write_text(
                    f'#!/bin/bash\nprintf "{name} %s\\n" "$*" >> "$CALL_LOG"\n')
            for path in (home / "bin").iterdir():
                path.chmod(0o755)
            (home / "config").mkdir()
            (home / "config/mimeapps.list").write_text(
                "x-scheme-handler/terminal=foot.desktop\n")
            env = dict(os.environ, PATH=f"{home}/bin:/usr/bin:/bin", CALL_LOG=str(log),
                       HOME=str(home), XDG_CONFIG_HOME=str(home / "config"))
            result = subprocess.run(["bash", str(script)], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = log.read_text()
            # Qt::Key | Qt::KeyboardModifiers: Meta+W, Alt+F4, Meta+Return, Meta+O.
            self.assertIn("kwin Window Close", calls)
            for keycode in ("268435543", "150994995", "285212676", "268435535"):
                self.assertIn(keycode, calls)
            # Un lanceur .desktop doit être enregistré avant de recevoir sa touche.
            self.assertLess(calls.index("doRegister"),
                            calls.index("285212676"))
            self.assertIn("kwriteconfig6 --file kdeglobals --group General "
                          "--key TerminalApplication foot", calls)

    def test_path_priority_deduplication_and_custom_tool_roots(self):
        with tempfile.TemporaryDirectory() as tmp:
            script = PROJECT / "shared/home/.config/shell/path.bash"
            env = dict(os.environ, HOME=tmp, PATH=f"/usr/bin:{tmp}/.local/bin:/bin",
                       CARGO_HOME=f"{tmp}/custom-cargo", GOPATH=f"{tmp}/custom-go:{tmp}/second-go")
            env.pop("GOBIN", None)
            result = subprocess.run(["/bin/bash", "--noprofile", "--norc", "-uc",
                                     'source "$1"; source "$1"; printf "%s" "$PATH"', "test", str(script)],
                                    env=env, capture_output=True, text=True, check=True)
            paths = result.stdout.split(":")
            self.assertEqual(paths[:4], [f"{tmp}/.local/bin", f"{tmp}/bin",
                                        f"{tmp}/custom-cargo/bin", f"{tmp}/custom-go/bin"])
            self.assertEqual(paths.count(f"{tmp}/.local/bin"), 1)
            self.assertNotIn(f"{tmp}/second-go/bin", paths)

    def test_default_go_path_works_under_nounset(self):
        env = dict(os.environ, HOME="/tmp/example-home", PATH="/usr/bin:/bin")
        for key in ("GOBIN", "GOPATH", "CARGO_HOME"):
            env.pop(key, None)
        result = subprocess.run(["bash", "--noprofile", "--norc", "-uc",
                                 'source "$1"; printf "%s" "$PATH"', "test",
                                 str(PROJECT / "shared/home/.config/shell/path.bash")],
                                env=env, capture_output=True, text=True, check=True)
        self.assertIn("/tmp/example-home/go/bin", result.stdout)
        self.assertIn("/tmp/example-home/.cargo/bin", result.stdout)

    def test_bashrc_preserves_nvm_fragments_and_local_overrides(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / ".bashrc.d").mkdir()
            (home / ".bashrc.d/site.bash").write_text('export SITE_MARKER=site\n')
            (home / ".bashrc.local").write_text('export LOCAL_MARKER=local\n')
            nvm = home / "custom-nvm"
            nvm.mkdir()
            (nvm / "nvm.sh").write_text('export NVM_MARKER=nvm; nvm() { :; }\n')
            (nvm / "bash_completion").write_text('export COMPLETION_MARKER=completion\n')
            env = dict(os.environ, HOME=tmp, NVM_DIR=str(nvm), PATH="/usr/bin:/bin", TERM="dumb")
            result = subprocess.run(["bash", "--noprofile", "--norc", "-ic",
                                     'source "$1"; printf "RESULT:%s:%s:%s:%s" "$SITE_MARKER" "$LOCAL_MARKER" "$NVM_MARKER" "$COMPLETION_MARKER"',
                                     "test", str(PROJECT / "asahi/home/.bashrc")],
                                    env=env, capture_output=True, text=True, check=True)
            self.assertIn("RESULT:site:local:nvm:completion", result.stdout)

    def test_noninteractive_login_config_sets_paths_without_nvm_activation(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / ".config/shell").mkdir(parents=True)
            shutil.copyfile(PROJECT / "shared/home/.config/shell/path.bash", home / ".config/shell/path.bash")
            shutil.copyfile(PROJECT / "asahi/home/.bashrc", home / ".bashrc")
            (home / ".nvm").mkdir()
            (home / ".nvm/nvm.sh").write_text('echo BAD_NVM_ACTIVATION\n')
            env = dict(os.environ, HOME=tmp, PATH="/usr/bin:/bin")
            result = subprocess.run(["bash", "--noprofile", "--norc", "-c",
                                     'source "$1"; printf "%s" "$PATH"', "test",
                                     str(PROJECT / "asahi/home/.bash_profile")],
                                    env=env, capture_output=True, text=True, check=True)
            self.assertTrue(result.stdout.startswith(f"{tmp}/.local/bin:"))
            self.assertNotIn("BAD_NVM_ACTIVATION", result.stdout)


class LuaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        name = ctypes.util.find_library("lua-5.4") or ctypes.util.find_library("lua5.4")
        if not name:
            raise unittest.SkipTest("liblua 5.4 unavailable (syntax/LSP mock tests)")
        cls.lib = ctypes.CDLL(name)
        cls.lib.luaL_newstate.restype = ctypes.c_void_p
        cls.lib.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        cls.lib.luaL_loadstring.restype = ctypes.c_int
        cls.lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
        cls.lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
        cls.lib.lua_pcallk.restype = ctypes.c_int
        cls.lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
        cls.lib.lua_tolstring.restype = ctypes.c_char_p
        cls.lib.lua_close.argtypes = [ctypes.c_void_p]

    def lua(self, text, execute=False):
        state = self.lib.luaL_newstate()
        try:
            self.lib.luaL_openlibs(state)
            code = self.lib.luaL_loadstring(state, text.encode())
            if code == 0 and execute:
                code = self.lib.lua_pcallk(state, 0, 0, 0, 0, None)
            error = self.lib.lua_tolstring(state, -1, None) if code else b""
            self.assertEqual(code, 0, error.decode() if error else "Lua failure")
        finally:
            self.lib.lua_close(state)

    def test_lua_syntax(self):
        for path in (PROJECT / "shared/home/.config/nvim").rglob("*.lua"):
            with self.subTest(path=path):
                self.lua(path.read_text())

    def test_system_lsps_are_enabled_and_mason_only_fills_gaps(self):
        text = (PROJECT / "shared/home/.config/nvim/init.lua").read_text()
        block = text[text.index("local lsp_commands = {"):text.index("-- INFO: Telescope")]
        prelude = '''
local lsp_servers = { clangd = {}, gopls = {}, lua_ls = {} }
local lsp_overrides = {}
local configured, enabled, missing = {}, {}, nil
vim = {
  fn = { executable = function(cmd) return (cmd == 'clangd' or cmd == 'gopls') and 1 or 0 end },
  tbl_keys = function(t) local r = {}; for k in pairs(t) do r[#r+1] = k end; return r end,
  tbl_filter = function(f, t) local r = {}; for _, v in ipairs(t) do if f(v) then r[#r+1] = v end end; return r end,
  tbl_extend = function(_, a, b) local r = {}; for k,v in pairs(a) do r[k] = v end; for k,v in pairs(b) do r[k] = v end; return r end,
  lsp = {
    config = function(name, config) configured[name] = config end,
    enable = function(name) assert(configured[name], 'enabled before configured'); enabled[name] = true end,
  },
}
require = function(name)
  if name == 'mason' then return { setup = function(opts) assert(opts.PATH == 'append') end } end
  if name == 'mason-lspconfig' then return { setup = function() end } end
  if name == 'mason-tool-installer' then return { setup = function(opts) missing = opts.ensure_installed end } end
  error('unexpected require: '..name)
end
'''
        assertions = '''
assert(enabled.clangd and enabled.gopls, 'system servers were not enabled')
assert(not enabled.lua_ls, 'missing executable enabled prematurely')
assert(#missing == 1 and missing[1] == 'lua_ls', 'Mason requested an existing server')
'''
        self.lua(prelude + block + assertions, execute=True)


if __name__ == "__main__":
    unittest.main()
