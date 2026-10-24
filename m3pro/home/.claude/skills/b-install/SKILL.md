---
name: b-install
description: REQUIRED before installing, upgrading or removing any software on this machine (MBP14OmarchyDev, "System B"). This is an Apple Silicon M3 Pro running Arch Linux ARM (aarch64, 16K pages) on hand-built dev kernels and a guarded dev GPU stack, so normal Arch/Linux install advice can break boot, GPU or sleep. Triggers: install, add, remove, uninstall, upgrade, update, pacman, yay, AUR, PKGBUILD, omarchy pkg/install/update, flatpak, AppImage, snap, docker/podman image, pip/pipx/uv, npm -g, cargo install, go install, mise, make install, build from source, DKMS, kernel module, firmware, driver, Hyprland/hyprpm plugin, Omarchy shell plugin.
---

# Installing software on System B

This machine is **not a normal Arch box**. Read this before proposing or running any install.
The owner keeps the full project notes on another machine (FIXEJVZ, `~/Documents/OmarchyM3/handoff.md`); they are not on this machine. Anything this skill marks **STOP** belongs to that project: explain, and let the owner decide.

## The machine

| | |
|---|---|
| Hardware | MacBook Pro 14" M3 Pro (`Mac15,6`, J514S / T6030), 12 cores, 18 GB, French Mac AZERTY keyboard |
| OS | Arch Linux ARM (Asahi ALARM base) + Omarchy 4.0.3rc4 (omarchy-mac), Hyprland 0.56, uwsm, quickshell |
| CPU arch | **aarch64 only.** No x86_64 emulation is installed (no FEX/box64/muvm/binfmt). x86 binaries, x86 AppImages, `amd64` container images and `arch=('x86_64')` AUR packages do not run |
| Page size | **16 KiB** (`getconf PAGESIZE` = 16384). Software built for 4K pages fails (typical: bundled jemalloc "Unsupported system page size", some prebuilt Electron/Chromium binaries, Wine) |
| Kernel | **custom, unpackaged:** `7.1.12-j514s-sleep-chg+` (GRUB default `omarchy-j514s-sleep-chg`). Other trees: `7.1.12-j514s+`, `7.1.12-j514s-sleep+`, stock `linux-asahi 7.2.12` (fallback only). No headers, no `/usr/lib/modules/*/build`. Modules must match the kernel's BTF exactly |
| Boot chain | m1n1 → U-Boot → GRUB, ESP `/boot` (FAT, **only ~128 MB free**). `boot.bin` is pinned via `/etc/default/update-m1n1` |
| GPU | Dev Mesa (G15 driver) in `/opt/mesa-g15`, loaded into the desktop session by `/etc/xdg/uwsm/env.d/51-mesa-g15` (`LD_LIBRARY_PATH`). System Mesa is **guarded** off the GPU (`/etc/drirc`, pacman `NoExtract` of `asahi_icd.json`) because it speaks a different GPU UAPI. A GPU fault means a fail-stop: no GPU until reboot |
| Video decode | VA-API via `v4l2_request` (`/etc/xdg/uwsm/env.d/52-avd-vaapi`) |
| pacman | `IgnorePkg = linux-asahi m1n1`; `NoExtract = usr/share/vulkan/icd.d/asahi_icd.json`. Repos: omarchy-aarch64, asahi-alarm, core, extra, alarm, aur, omarchy |
| Snapshots | snapper `root` config, **no automatic snapshots** (no snap-pac) |
| sudo | needs a password. **Claude cannot run sudo here** (no TTY); the owner runs it in a terminal. Passwordless sudo was declined: don't propose it |

## Rules

1. **Read-only first.** Find out what the request needs, run the preflight (below), explain the plan and its risks, then hand the owner the exact command. Never `--noconfirm` (so not `omarchy-pkg-add`, which adds it). One install at a time.
2. **Never upgrade the system as a side effect.** Plain `pacman -Syu`/`yay -Syu` is blocked by Omarchy's guard hook. Don't bypass it (`OMARCHY_ALLOW_DIRECT_PACMAN`), never use `pacman -Sy <pkg>` (partial upgrade), and don't run `omarchy update` yourself. If an install needs newer libraries than the ones installed (the preflight shows `UPGRADE` lines), STOP: the owner runs `omarchy update` as its own step, followed by the checks in "After `omarchy update`".
3. **STOP and ask the owner, without proposing a workaround, for anything that touches:**
   - **kernel or boot:** `linux*`, `*-headers`, `dkms`/`*-dkms`, out-of-tree modules, `m1n1*`, `uboot-asahi`, `asahi-*` (incl. `asahi-scripts`, which owns `update-m1n1`), `grub`, `mkinitcpio*`, `/boot`, `/etc/default/grub`, `/etc/grub.d`, `/etc/mkinitcpio*`, `/etc/modprobe.d`, kernel command line;
   - **GPU stack:** `mesa*`, `vulkan-*`, `libdrm`, `libglvnd`, `lib32-*`, `/etc/drirc`, `/opt/mesa-g15`, `/etc/xdg/uwsm/env.d/5*`, anything that sets `LD_LIBRARY_PATH`, `VK_*`, `LIBGL_*`, `MESA_*`, `__EGL_*`, `LIBVA_*`;
   - **desktop core:** `omarchy*`, `hyprland`, `aquamarine`, `quickshell`, `qt6-base`, `sddm`, `uwsm`, `systemd*`, `pipewire*`, `wireplumber`, `linux-firmware*`, `cryptsetup`, `btrfs-progs`, `snapper`;
   - **the dev toolchain** (kernel and Mesa builds in `~/src/m3dev` need them): `clang22`/`llvm22*`, `rust-bindgen`, `libclc`, `spirv-llvm-translator`, `rustup`. Never change `rustup default` and never remove the `1.89.0` or `1.93.1` toolchains;
   - **files under `/etc/pacman.conf`, `/usr/local/lib`, `/etc/systemd/system`, or `/root`.**
4. **Software that brings its own GPU drivers bypasses the guards:** Flatpak (not installed), Snap, AppImages bundling Mesa/Vulkan, containers given `/dev/dri`, apps that clear `LD_LIBRARY_PATH`. Don't install or run these with GPU access without the owner's explicit OK. A CLI tool in a container without `/dev/dri` is fine.
5. **Downloaded code is untrusted.** Never `curl … | sh`. Download to a file, read it, then run it. For AUR: `yay -Si <pkg>` (check `Architecture` includes `aarch64` or `any`), then `yay -G <pkg>` into a scratch dir and read the PKGBUILD and any `.install` file before building. Read an `omarchy-install-*` helper before suggesting it (it may be x86-only or pull in more than asked).
6. **Shell plugins:** only from the official marketplace (omarchyplugins.com, repo `omacom/omarchy-plugin-marketplace`). **omarchystore.com is a typo-squat** with a root-install hook. `omarchy plugin add <url>` without `--enable`, read the code, compare `git rev-parse HEAD` with the marketplace "Verified snapshot", check `grep -rn 'Color\.'` (bare `Color` is undefined on Qt 6.12; use `Commons.Color`), then `omarchy plugin enable <id>`. Never follow a plugin's advice to run `omarchy update`.

## Choosing the install route (prefer earlier ones)

1. **Repo package:** `sudo pacman -S --needed <pkg>` (no `-y`, no `--noconfirm`).
2. **User-level, no sudo** (Claude may run these itself; reversible): `mise use -g <tool>@<ver>` for language runtimes; `cargo install` (default toolchain 1.99.1); `npm -g` via mise's node; Python apps in a venv (`python -m venv`). System Python 3.14 is externally managed: never `pip install --break-system-packages`, never `sudo pip`. pipx and uv are not installed.
3. **AUR via yay**, after the rule-5 review. yay asks for sudo itself, so the owner runs it.
4. **Build from source** under `~/src` (never in `~/src/m3dev`, which holds the kernel/Mesa work), install to `~/.local`. `make install` to `/usr` is a STOP.

## Preflight and post-checks

Read-only helper, no sudo: `bash ~/.claude/skills/b-install/b-install-check.sh pre <pkg>...`
- Shows the full transaction (dependencies included).
- Flags `STOP` (rule 3 names), `UPGRADE` (an installed package would be upgraded, i.e. a partial upgrade: rule 2) and `CAUTION` (firmware/systemd/cryptsetup packages rebuild the initramfs of **all four** kernels via the mkinitcpio hook, which is expected).
- Also lists pending system updates.
- `target not found` means the package isn't in the repos; check the AUR (`yay -Si`) or a user-level route.

After the owner's install: `bash ~/.claude/skills/b-install/b-install-check.sh post`. It confirms `boot.bin`, the GRUB default, the GPU guards, pacman.conf and the m1n1 pin are unchanged, that no `asahi_icd.json` appeared, that no unit failed, and it shows the tail of `/var/log/pacman.log` (the install record, so no extra log is needed). If anything reads `CHANGED`, stop and tell the owner; don't try to fix it. (If the owner changed one of these files on purpose, the constant in the script needs updating.)

## Commands the owner types

The owner runs sudo commands in a separate terminal, so keep them short and literal:
- **No `|`, `\`, `<placeholders>`** (AZERTY plus zsh redirects).
- Compute values in the command or a script, not by hand.
- For a non-pacman sudo step whose output you need, wrap it: `script -q -c "sudo …" ~/.local/state/b-install/NAME.log`, then read the log.
- Anything beyond a single package command (editing `/etc`, enabling system units, multi-step installs) should be a short reviewed script that the owner reads before running.

## Afterwards

- Test the program as a normal desktop app. From a Claude shell, the session's GPU environment isn't set, so GPU apps fall back to llvmpipe here; that's expected. Launch with `systemd-run --user --collect <cmd>` to get the desktop environment.
- Append one line to `~/.local/state/b-install/journal.md`: date, what, route, packages added (from pacman.log), how to remove it. The owner copies this into the project notes. Keep `~` tidy: no logs or scratch files at the top level.
- Removal: `sudo pacman -Rns <pkg>` (check the preflight-style list first: `pacman -Rns --print <pkg>`; it must not drop anything in rule 3).

## After `omarchy update` (owner's step, never Claude's)

The update reverts local fixes. Tell the owner to:
- re-run `sudo bash ~/b4-shell-fixes.sh` (QtQuick stopgap and lock fix);
- run the `post` check;
- confirm `grep GRUB_DEFAULT= /etc/default/grub` shows `omarchy-j514s-sleep-chg`, and run `bash ~/stage7/b-stage7e-appledrm-hold.sh status`;
- if `mesa` was updated, re-run the GPU guard test from the project notes.
