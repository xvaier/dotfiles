"""Single-file SSH transfer protocol. File bytes never enter tool output."""
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import tempfile


def transfer():
    direction, filename, overwrite, expected = sys.argv[1:]
    target = Path(filename)
    digest = hashlib.sha256()
    size = 0
    if direction == "download":
        fd = os.open(target, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, "rb") as source:
            if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
                raise ValueError("Source must be a regular, non-symlink file")
            while chunk := source.read(1024 * 1024):
                digest.update(chunk)
                size += len(chunk)
                sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
    else:
        if not target.parent.is_dir():
            raise ValueError("Remote destination directory must already exist")
        fd, temporary = tempfile.mkstemp(prefix=".pi-proxmox-transfer-", dir=target.parent)
        try:
            with os.fdopen(fd, "wb") as output:
                while chunk := sys.stdin.buffer.read(1024 * 1024):
                    digest.update(chunk)
                    size += len(chunk)
                    output.write(chunk)
                output.flush()
                os.fsync(output.fileno())
            if digest.hexdigest() != expected:
                raise ValueError("Upload checksum mismatch; destination not replaced")
            if overwrite == "true":
                if target.is_symlink() or (target.exists() and not target.is_file()):
                    raise ValueError("Refusing to replace a symlink or non-regular file")
                os.replace(temporary, target)
            else:
                # Atomic no-clobber publication, including dangling symlinks.
                os.link(temporary, target)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    print(json.dumps({"sha256": digest.hexdigest(), "size": size}), file=sys.stderr)


try:
    transfer()
except Exception as error:
    # Do not include file contents or exception arguments in logs.
    print("Transfer failed: " + type(error).__name__, file=sys.stderr)
    sys.exit(1)
