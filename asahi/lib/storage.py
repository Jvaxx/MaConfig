"""Small filesystem primitives shared by the Asahi scripts (stdlib only)."""
from __future__ import annotations

import filecmp
import os
from pathlib import Path
import shutil
import stat
import uuid
from datetime import datetime, timezone


def exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def backup_name(path: Path) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    return path.with_name(f"{path.name}.bak.{stamp}.{uuid.uuid4().hex[:8]}")


def publish(staged: Path, destination: Path, *, backup_directory: Path | None = None) -> Path | None:
    """Rename on the same filesystem; never delete the previous version.

    On a failed second rename (including Ctrl-C), put the backup back. Backups
    live outside the temporary staging directory, so even a power failure or
    SIGKILL cannot make TemporaryDirectory cleanup delete the previous version.
    """
    backup = backup_name(destination) if exists(destination) else None
    if backup is not None:
        if backup_directory is not None:
            backup_directory.mkdir(parents=True, exist_ok=True)
            backup = backup_directory / backup.name
        destination.replace(backup)
    try:
        staged.replace(destination)
    except BaseException:
        if backup is not None:
            backup.replace(destination)
        raise
    return backup


def remove(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def copy_file(source: str | Path, destination: str | Path) -> str:
    """Preserve mode/times, not Arch owners or SELinux/security xattrs."""
    source, destination = Path(source), Path(destination)
    shutil.copyfile(source, destination)
    shutil.copymode(source, destination)
    info = source.stat()
    os.utime(destination, ns=(info.st_atime_ns, info.st_mtime_ns))
    return str(destination)


def copy_tree(source: Path, destination: Path, *, ignore, copy_function=copy_file) -> None:
    """copytree equivalent without copying directory security xattrs either."""
    destination.mkdir()
    children = list(source.iterdir())
    skipped = ignore(str(source), [p.name for p in children])
    for child in children:
        if child.name in skipped:
            continue
        target = destination / child.name
        if child.is_symlink():
            target.symlink_to(os.readlink(child))
        elif child.is_dir():
            copy_tree(child, target, ignore=ignore, copy_function=copy_function)
        else:
            copy_function(child, target)
    shutil.copymode(source, destination)
    info = source.stat()
    os.utime(destination, ns=(info.st_atime_ns, info.st_mtime_ns))


def identical(a: Path, b: Path) -> bool:
    """Content comparison, not just size/mtime; never follow a destination link."""
    if a.is_symlink() or b.is_symlink():
        return a.is_symlink() and b.is_symlink() and os.readlink(a) == os.readlink(b)
    if not a.exists() or not b.exists():
        return False
    if stat.S_IMODE(a.stat().st_mode) != stat.S_IMODE(b.stat().st_mode):
        return False
    if a.is_file() and b.is_file():
        return filecmp.cmp(a, b, shallow=False)
    if a.is_dir() and b.is_dir():
        names = {p.name for p in a.iterdir()}
        return names == {p.name for p in b.iterdir()} and all(
            identical(a / name, b / name) for name in names
        )
    return False
