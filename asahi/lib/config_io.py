#!/usr/bin/env python3
"""Validated, staged config restore/sync for Asahi; never executes sourced configs."""
from __future__ import annotations

import argparse
from contextlib import ExitStack, contextmanager, nullcontext
from dataclasses import dataclass
from datetime import datetime, timezone
import fcntl
import fnmatch
import os
from pathlib import Path, PurePosixPath
import shutil
import signal
import subprocess
import sys
import tempfile

from storage import copy_file, copy_tree, identical, publish, remove

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parent


@dataclass
class Entry:
    relative: str
    repository: Path


def manifest(path: Path, root: Path) -> list[Entry]:
    entries: list[Entry] = []
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        text = raw.split("#", 1)[0].strip()
        if not text:
            continue
        shared = text.startswith("shared:")
        rel = text.removeprefix("shared:") if shared else text
        parts = rel.split("/")
        if (rel.startswith("/") or any(p in ("", ".", "..", ".git") for p in parts)
                or any(c in rel for c in "\n\r\t:\\") or rel.startswith("-")):
            raise ValueError(f"{path}:{number}: chemin invalide: {text!r}")
        for entry in entries:
            if (rel == entry.relative or rel.startswith(entry.relative + "/")
                    or entry.relative.startswith(rel + "/")):
                raise ValueError(f"Entrées dupliquées/imbriquées: {rel}, {entry.relative}")
        base = root / ("shared/home" if shared else "asahi/home")
        if not base.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"Arbre du dépôt redirigé hors du dépôt: {base}")
        entries.append(Entry(rel, base / rel))
    if not entries:
        raise ValueError("MANIFEST vide: aucune opération effectuée")
    return entries


@contextmanager
def operation_lock(root: Path):
    # Persistent inode: unlinking a flock file would let another process lock
    # a different inode. It is ignored by Git and never created in dry-run.
    with (root / "asahi/.operation.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise RuntimeError("Une autre opération Asahi est en cours") from exc
        yield


def ignored(_directory: str, names: list[str]) -> set[str]:
    return {n for n in names if n == ".git" or fnmatch.fnmatch(n, "*.bak.*")
            or n.startswith(".maconfig-stage-")}


def validate_tree(path: Path) -> None:
    """Allow relative internal symlinks, not dangling/external links or devices."""
    if path.is_file():
        return
    if not path.is_dir():
        raise ValueError(f"Source absente ou non régulière: {path}")
    base = path.resolve()
    for directory, dirs, files in os.walk(base, followlinks=False):
        skip = ignored(directory, dirs + files)
        dirs[:] = [d for d in dirs if d not in skip]
        for name in dirs + [f for f in files if f not in skip]:
            child = Path(directory) / name
            if child.is_symlink():
                target = os.readlink(child)
                if (PurePosixPath(target).is_absolute() or not child.exists()
                        or not child.resolve().is_relative_to(base)):
                    raise ValueError(f"Lien non portable dans la sauvegarde: {child} -> {target}")
                if ignored("", list(child.resolve().relative_to(base).parts)):
                    raise ValueError(f"Lien vers un fichier exclu de la sauvegarde: {child}")
            elif not (child.is_file() or child.is_dir()):
                raise ValueError(f"Fichier spécial non sauvegardable: {child}")


def safe_parent(destination: Path, allowed_root: Path) -> None:
    # The leaf itself may be a symlink; it is renamed, NEVER written through.
    # Symlinked parent directories must not redirect writes outside the root.
    if not destination.parent.resolve().is_relative_to(allowed_root.resolve()):
        raise ValueError(f"Parent redirigé hors de la destination: {destination}")


def execute(command: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(command, check=True, text=True, **kwargs)


def git(root: Path, *args: str, **kwargs) -> subprocess.CompletedProcess:
    return execute(["git", "--literal-pathspecs", "-C", str(root), *args], **kwargs)


def metadata() -> dict[str, str]:
    now = datetime.now(timezone.utc).isoformat()
    # Store /etc/os-release as text, never source/eval it in a subprocess.
    os_release = Path("/etc/os-release")
    distro = "unknown"
    if os_release.exists():
        for line in os_release.read_text().splitlines():
            if line.startswith("PRETTY_NAME="):
                distro = line.split("=", 1)[1].strip('"')
    nvim = "absent"
    if shutil.which("nvim"):
        result = subprocess.run(["nvim", "--version"], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout:
            nvim = result.stdout.splitlines()[0]
    state = "\n".join([
        f"distro={distro}", f"kernel={os.uname().release}", f"arch={os.uname().machine}",
        f"desktop={os.environ.get('XDG_CURRENT_DESKTOP', 'unknown')}",
        f"nvim={nvim}", f"synced_at={now}", f"hostname={os.uname().nodename}", "",
    ])
    result = {"STATE": state}
    if shutil.which("dnf"):
        # --userinstalled already selects installed packages; DNF5 rejects
        # combining it with --installed.
        packages = execute([
            "dnf", "--cacheonly", "repoquery", "--userinstalled",
            "--qf", "%{name}\n",
        ], stdout=subprocess.PIPE).stdout
        result["packages.installed.txt"] = (
            f"# Paquets utilisateur — {now}\n"
            "# Référence seulement; liste voulue: packages.dnf.\n"
            + "".join(p + "\n" for p in sorted(set(packages.splitlines())) if p)
        )
    else:
        print("dnf absent: packages.installed.txt conservé, pas régénéré", file=sys.stderr)
    return result


def transfer(args: argparse.Namespace, root: Path, home: Path) -> None:
    restoring = args.action == "restore"
    entries = manifest(root / "asahi/MANIFEST", root)
    operations: list[tuple[Path, Path, str]] = []
    linked = 0
    physical_destinations: list[Path] = []
    # Check EVERYTHING before staging, including sources and symlinked parents.
    for entry in entries:
        local = home / entry.relative
        src, dst = (entry.repository, local) if restoring else (local, entry.repository)
        repository_tree = root / ("shared/home" if entry.repository.is_relative_to(root / "shared") else "asahi/home")
        allowed = home if restoring else repository_tree
        if not src.exists():
            raise ValueError(f"Source absente: {src} (aucune copie commencée)")
        if src.resolve() == dst.resolve():
            print(f"  déjà lié: {entry.relative}")
            linked += 1
            continue
        safe_parent(dst, allowed)
        if restoring and dst.parent.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"La destination HOME redirige une écriture dans le dépôt: {dst}")
        physical = dst.parent.resolve() / dst.name
        if any(physical.is_relative_to(p) or p.is_relative_to(physical) for p in physical_destinations):
            raise ValueError(f"Destinations physiques dupliquées/imbriquées: {dst}")
        physical_destinations.append(physical)
        if restoring and not src.resolve().is_relative_to(root):
            raise ValueError(f"Source du dépôt redirigée hors du dépôt: {src}")
        validate_tree(src)
        operations.append((src, dst, entry.relative))

    if args.action == "sync" and args.commit:
        if git(root, "diff", "--cached", "--name-only", "-z", stdout=subprocess.PIPE).stdout:
            raise ValueError("Index Git non vide: commiter/désindexer vos changements avant --commit")

    if args.dry_run:
        for src, dst, _ in operations:
            print(f"  {'lier' if args.link else 'copier'}: {src} -> {dst}")
        if not restoring:
            print("  régénérer STATE et packages.installed.txt (aucune requête DNF en simulation)")
        print("Simulation: aucun fichier modifié.")
        return

    if restoring and not args.yes:
        print(f"Destination: {home}; {len(operations)} entrée(s), {linked} lien(s) intact(s).")
        print("Les anciennes versions restent dans *.bak.<date>.<identifiant>.")
        print(".bashrc/.bash_profile sont remplacés, pas fusionnés; conserver les ajouts locaux.")
        if input("Continuer ? [y/N] ").lower() != "y":
            return

    # Query metadata before copying; a DNF error must not truncate the old list.
    records = {} if restoring else metadata()
    prepared: list[tuple[Path, Path, str]] = []
    changed: list[tuple[Path, Path | None]] = []
    unchanged = 0
    with ExitStack() as stack:
        for src, dst, label in operations:
            dst.parent.mkdir(parents=True, exist_ok=True)
            tmp = Path(stack.enter_context(tempfile.TemporaryDirectory(
                prefix=".maconfig-stage-", dir=dst.parent)))
            staged = tmp / "new"
            if args.link:
                staged.symlink_to(src.resolve(), target_is_directory=src.is_dir())
            elif src.is_dir():
                copy_tree(src, staged, ignore=ignored, copy_function=copy_file)
            else:
                copy_file(src, staged)
            if identical(staged, dst):
                unchanged += 1
                print(f"  identique: {label}")
            else:
                prepared.append((staged, dst, label))
        for name, text in records.items():
            dst = root / "asahi" / name
            tmp = Path(stack.enter_context(tempfile.TemporaryDirectory(
                prefix=".maconfig-stage-", dir=dst.parent)))
            staged = tmp / "new"
            staged.write_text(text)
            if not identical(staged, dst):
                prepared.append((staged, dst, name))

        # All copies finished successfully. Only now replace destinations.
        try:
            for staged, dst, label in prepared:
                backup = publish(staged, dst)
                changed.append((dst, backup))
                print(f"  {'restauré' if restoring else 'sauvé'}: {label}")
                if backup:
                    print(f"    sauvegarde précédente: {backup}")
        except BaseException:
            for dst, backup in reversed(changed):
                remove(dst)
                if backup is not None:
                    backup.replace(dst)
            raise

    print(f"Modifiés: {len(changed)}; identiques: {unchanged}; liens intacts: {linked}")
    if not restoring and args.commit:
        # Only paths managed by this manifest, plus freshly written metadata.
        # No scripts, macos/, quattro/, or unrelated shared configs get staged.
        paths = [str(e.repository.relative_to(root)) for e in entries]
        paths += [f"asahi/{name}" for name in records]
        git(root, "add", "-A", "--", *paths)
        result = subprocess.run(["git", "-C", str(root), "diff", "--cached", "--quiet"])
        if result.returncode == 1:
            git(root, "commit", "-m", f"asahi: sync config {datetime.now():%Y-%m-%d}")
        elif result.returncode != 0:
            raise RuntimeError("Impossible de vérifier l'index Git")
        else:
            print("Rien à commiter.")
    if restoring:
        print("Suite: RESTORE.md — nouveau shell, Compose, Neovim, terminal Plasma, Podman opt-in.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("restore", "sync"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--yes", "-y", action="store_true")
    parser.add_argument("--link", action="store_true")
    parser.add_argument("--commit", action="store_true")
    args = parser.parse_args()
    if args.action == "sync" and (args.link or args.yes):
        parser.error("--link/--yes sont réservés à restore")
    if args.action == "restore" and args.commit:
        parser.error("--commit est réservé à sync")
    home_value = os.environ.get("HOME", "")
    if not home_value or not Path(home_value).is_absolute():
        parser.error("HOME doit être un chemin absolu non vide")
    home = Path(home_value).resolve()
    if home == Path("/") or not home.is_dir():
        parser.error("HOME doit être un dossier utilisateur existant, pas /")
    if os.geteuid() == 0 and not args.dry_run:
        parser.error("Lancer comme utilisateur, sans sudo")
    try:
        with nullcontext() if args.dry_run else operation_lock(ROOT):
            transfer(args, ROOT, home)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError, EOFError) as exc:
        print(f"ERREUR: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Interrompu; vérifier les sauvegardes *.bak.*.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    sys.exit(main())
