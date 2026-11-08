#!/usr/bin/env python3
"""Check the index, not worktree copies; never print matching private values."""
import pathlib
import subprocess
import sys


def git(*args):
    return subprocess.check_output(["git", *args])


root = pathlib.Path(git("rev-parse", "--show-toplevel").decode().strip())
manifest = git("show", ":1password-files").decode()
private_paths = {
    line.split("|", 1)[0]
    for line in manifest.splitlines()
    if line.strip() and not line.startswith("#")
}
private_paths.update({"agents/claude/settings.local.json", "privacy-patterns.local"})
patterns_file = root / "privacy-patterns.local"
if "--require-local" in sys.argv and not patterns_file.is_file():
    sys.exit("Publication guard: restore privacy-patterns.local from 1Password before committing.")
patterns = [b"/" + b"Users/"]
if patterns_file.is_file():
    patterns.extend(
        line.strip() for line in patterns_file.read_bytes().splitlines()
        if line.strip() and not line.startswith(b"#")
    )

failed = False
for entry in git("ls-files", "--stage", "-z").split(b"\0"):
    if not entry:
        continue
    metadata, raw_path = entry.split(b"\t", 1)
    mode, oid, stage = metadata.split()
    path = raw_path.decode(errors="surrogateescape")
    if stage != b"0":
        print(f"Publication guard: unresolved conflict in {path!r}", file=sys.stderr)
        failed = True
        continue
    if path in private_paths or path.startswith("claude/") or path.endswith(".local.json"):
        print(f"Publication guard: private file is tracked: {path!r}", file=sys.stderr)
        failed = True
        continue
    if mode == b"160000":
        continue
    content = git("cat-file", "blob", oid.decode())
    if any(pattern.lower() in content.lower() for pattern in patterns):
        print(f"Publication guard: private hostname or machine path in {path!r}", file=sys.stderr)
        failed = True

sys.exit(1 if failed else 0)
