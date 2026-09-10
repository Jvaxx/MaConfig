#!/usr/bin/env python3
"""Install pinned ARM64 binaries/fonts without executing a remote shell installer."""
from __future__ import annotations

import argparse
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from urllib.parse import urlparse

from config_io import operation_lock, safe_parent
from storage import identical, publish, remove

HERE = Path(__file__).resolve().parents[1]


def download(asset: dict, destination: Path) -> None:
    url = asset["url"]
    if urlparse(url).scheme != "https":
        raise ValueError("Les assets doivent être téléchargés en HTTPS")
    expected = asset["sha256"]
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise ValueError("SHA-256 épinglé absent/invalide")
    digest = hashlib.sha256()
    size = 0
    request = urllib.request.Request(url, headers={"User-Agent": "MaConfig-Asahi/1"})
    with urllib.request.urlopen(request, timeout=60) as response, destination.open("wb") as out:
        if urlparse(response.url).scheme != "https":
            raise ValueError("Redirection non HTTPS refusée")
        while chunk := response.read(1024 * 1024):
            size += len(chunk)
            if size > 256 * 1024 * 1024:
                raise ValueError("Archive anormalement volumineuse")
            out.write(chunk)
            digest.update(chunk)
    if digest.hexdigest() != expected:
        raise ValueError(f"SHA-256 incorrect pour {url}; rien n'a été installé")


def unpack(asset: dict, archive: Path, destination: Path) -> dict[str, Path]:
    """Read selected regular members; never tar.extractall untrusted paths."""
    selected: dict[str, Path] = {}
    seen: set[str] = set()
    with tarfile.open(archive, "r:*") as tar:
        for member in tar:
            name = str(PurePosixPath(member.name))
            if (name.startswith("/") or ".." in PurePosixPath(name).parts
                    or member.issym() or member.islnk() or not (member.isfile() or member.isdir())):
                raise ValueError(f"Membre d'archive non sûr: {member.name}")
            if member.isdir():
                continue
            if name in seen:
                raise ValueError(f"Membre dupliqué: {name}")
            seen.add(name)
            if "fonts" in asset:
                base = PurePosixPath(name).name
                if not (base.lower().endswith((".ttf", ".otf", ".txt"))
                        or base.lower().startswith(("license", "ofl"))):
                    continue
                target = base
            else:
                target = asset["binaries"].get(name)
                if target is None:
                    continue
            if Path(target).name != target or target in ("", ".", "..") or target in selected:
                raise ValueError(f"Nom de destination invalide/dupliqué: {target}")
            if member.size > 512 * 1024 * 1024:
                raise ValueError(f"Fichier anormalement volumineux: {name}")
            path = destination / target
            source = tar.extractfile(member)
            if source is None:
                raise ValueError(f"Membre illisible: {name}")
            with source, path.open("wb") as output:
                shutil.copyfileobj(source, output)
            path.chmod(0o644 if "fonts" in asset else 0o755)
            selected[target] = path
    if "fonts" in asset:
        if not any(p.suffix.lower() in (".ttf", ".otf") for p in selected.values()):
            raise ValueError("L'archive ne contient aucune police")
    elif set(selected) != set(asset["binaries"].values()):
        raise ValueError("Un binaire attendu manque dans l'archive")
    return selected


def font_receipt_valid(destination: Path, asset: dict) -> bool:
    if destination.is_symlink():
        return False
    try:
        receipt = json.loads((destination / ".maconfig-asset.json").read_text())
        return (receipt["sha256"] == asset["sha256"] and bool(receipt["files"])
                and all(Path(name).name == name and not (destination / name).is_symlink()
                        and hashlib.sha256((destination / name).read_bytes()).hexdigest() == digest
                        for name, digest in receipt["files"].items()))
    except (OSError, ValueError, KeyError, TypeError):
        return False


def install(asset: dict, home: Path, verify_only: bool = False) -> None:
    font_name = asset.get("fonts", "unused")
    if Path(font_name).name != font_name or font_name in ("", ".", ".."):
        raise ValueError("Nom de dossier de polices invalide")
    font_destination = home / ".local/share/fonts" / font_name
    font_backups = home / ".local/state/maconfig/font-backups"
    if not verify_only and "fonts" in asset:
        safe_parent(font_destination, home)
        safe_parent(font_backups / "placeholder", home)
    if not verify_only and "fonts" in asset and font_receipt_valid(font_destination, asset):
        print(f"Police déjà vérifiée: {font_destination}")
        # A previous fc-cache failure should be retried, not silently forgotten.
        subprocess.run(["fc-cache", "-f", str(font_destination)], check=True)
        return
    with tempfile.TemporaryDirectory(prefix="maconfig-download-") as work:
        work = Path(work)
        archive = work / "asset.tar"
        print(f"Téléchargement vérifié: {asset['url']}")
        download(asset, archive)
        payload = work / "payload"
        payload.mkdir()
        selected = unpack(asset, archive, payload)
        if verify_only:
            print(f"SHA-256 et contenu valides: {len(selected)} fichier(s); rien installé")
            return
        with ExitStack() as stack:
            prepared = []
            if "fonts" in asset:
                receipt = {"sha256": asset["sha256"], "version": asset["version"],
                           "files": {n: hashlib.sha256(p.read_bytes()).hexdigest()
                                     for n, p in selected.items()}}
                (payload / ".maconfig-asset.json").write_text(json.dumps(receipt, indent=2) + "\n")
                destinations = [(payload, font_destination)]
            else:
                destinations = [(p, home / ".local/bin" / name) for name, p in selected.items()]
            # Stage on the destination filesystem; a failed download/extraction
            # or copy cannot remove an existing binary/font installation.
            for source, dst in destinations:
                safe_parent(dst, home)
                dst.parent.mkdir(parents=True, exist_ok=True)
                tmp = Path(stack.enter_context(tempfile.TemporaryDirectory(
                    prefix=".maconfig-stage-", dir=dst.parent)))
                staged = tmp / "new"
                if source.is_dir():
                    shutil.copytree(source, staged)
                else:
                    shutil.copy2(source, staged)
                if not identical(staged, dst):
                    prepared.append((staged, dst))
            changed = []
            try:
                for staged, dst in prepared:
                    # Font backups must be OUTSIDE the fontconfig search tree,
                    # otherwise old versions remain discoverable as duplicates.
                    if "fonts" in asset:
                        backup = publish(staged, dst, backup_directory=font_backups)
                    else:
                        backup = publish(staged, dst)
                    changed.append((dst, backup))
                    print(f"Installé: {dst}" + (f" (ancien: {backup})" if backup else ""))
            except BaseException:
                for dst, backup in reversed(changed):
                    remove(dst)
                    if backup is not None:
                        backup.replace(dst)
                raise
    if "fonts" in asset:
        subprocess.run(["fc-cache", "-f", str(font_destination)], check=True)


def main() -> int:
    assets = json.loads((HERE / "assets.json").read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name", choices=assets)
    parser.add_argument("--verify-only", action="store_true", help="Télécharger/vérifier, sans installer ni exécuter")
    args = parser.parse_args()
    if not args.verify_only and (os.geteuid() == 0 or os.uname().machine != "aarch64"):
        parser.error("Installation réservée à un utilisateur non root sur aarch64")
    value = os.environ.get("HOME", "")
    if not value or not Path(value).is_absolute() or Path(value).resolve() == Path("/"):
        parser.error("HOME utilisateur absolu requis")
    try:
        if args.verify_only:
            install(assets[args.name], Path(value).resolve(), verify_only=True)
        else:
            with operation_lock(HERE.parent):
                install(assets[args.name], Path(value).resolve())
    except (OSError, ValueError, tarfile.TarError, subprocess.CalledProcessError) as exc:
        print(f"ERREUR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
