#!/usr/bin/env python3
"""Exercise publication guards and the hook against real temporary Git indexes."""
import os
import pathlib
import secrets
import shutil
import string
import subprocess
import tempfile
import unittest

GUARD = pathlib.Path(__file__).with_name("check-publication.py").resolve()
HOOK = GUARD.parent.parent / ".githooks/pre-commit"
BETTERLEAKS = shutil.which("betterleaks")
BASH = shutil.which("bash") or "/bin/bash"


class GitRepoTestCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.git("init", "-q")
        self.put("1password-files", "private.local.json|private config\n")
        self.put("privacy-patterns.local", "internal.example.test\n")
        self.git("add", "1password-files")

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root)

    def put(self, path, content):
        (self.root / path).write_text(content)

    def check(self):
        return subprocess.run(
            ["python3", str(GUARD), "--require-local"], cwd=self.root,
            capture_output=True, text=True,
        )


class PublicationTests(GitRepoTestCase):
    def test_clean(self):
        self.assertEqual(self.check().returncode, 0)

    def test_private_path(self):
        self.put("private.local.json", "{}")
        self.git("add", "private.local.json")
        self.assertNotEqual(self.check().returncode, 0)

    def test_staged_content_not_worktree(self):
        self.put("config", "internal.example.test")
        self.git("add", "config")
        self.put("config", "sanitized")
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("internal.example.test", result.stderr)
        self.git("add", "config")
        self.assertEqual(self.check().returncode, 0)

    def test_machine_path(self):
        self.put("config", "/" + "Users/somebody/private")
        self.git("add", "config")
        self.assertNotEqual(self.check().returncode, 0)

    def test_requires_local_patterns(self):
        (self.root / "privacy-patterns.local").unlink()
        self.assertNotEqual(self.check().returncode, 0)


class HookTests(GitRepoTestCase):
    def setUp(self):
        super().setUp()
        (self.root / "scripts").mkdir()
        shutil.copyfile(GUARD, self.root / "scripts/check-publication.py")
        self.secret = "ghp_" + "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(36))

    def hook(self, env=None):
        return subprocess.run(
            [BASH, str(HOOK)], cwd=self.root, env=env,
            capture_output=True, text=True, timeout=30,
        )

    def limited_env(self):
        binary_dir = self.root / "bin"
        binary_dir.mkdir()
        for name in ("git", "python3"):
            (binary_dir / name).symlink_to(shutil.which(name))
        return {**os.environ, "PATH": str(binary_dir)}

    def test_private_guard_runs_before_scanner(self):
        self.put("config", "internal.example.test")
        self.git("add", "config")
        result = self.hook(self.limited_env())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Publication guard", result.stderr)
        self.assertNotIn("brew install betterleaks", result.stderr)
        self.assertNotIn("internal.example.test", result.stderr)

    def test_scanner_missing_blocks_commit(self):
        result = self.hook(self.limited_env())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("brew install betterleaks", result.stderr)

    def test_scanner_error_blocks_commit(self):
        env = self.limited_env()
        scanner = self.root / "bin/betterleaks"
        scanner.write_text("#!/bin/sh\nexit 2\n")
        scanner.chmod(0o700)
        self.assertEqual(self.hook(env).returncode, 2)

    @unittest.skipUnless(BETTERLEAKS, "Betterleaks is not installed")
    def test_clean_staged_change_passes(self):
        self.put("config", "public setting\n")
        self.git("add", "config")
        self.assertEqual(self.hook().returncode, 0)

    @unittest.skipUnless(BETTERLEAKS, "Betterleaks is not installed")
    def test_staged_secret_blocks_even_when_worktree_is_cleaned(self):
        self.put("config", self.secret + "\n")
        self.git("add", "config")
        self.put("config", "sanitized\n")
        # Explicit --validation=false must take precedence over environment defaults.
        result = self.hook({**os.environ, "BETTERLEAKS_VALIDATION": "true"})
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(self.secret, result.stdout + result.stderr)
        self.assertNotIn("validation enabled", (result.stdout + result.stderr).lower())

    @unittest.skipUnless(BETTERLEAKS, "Betterleaks is not installed")
    def test_unstaged_secret_is_not_scanned(self):
        self.put("config", "public setting\n")
        self.git("add", "config")
        self.put("config", self.secret + "\n")
        self.assertEqual(self.hook().returncode, 0)

    @unittest.skipUnless(BETTERLEAKS, "Betterleaks is not installed")
    def test_removing_secret_passes_hook_but_history_scan_still_finds_it(self):
        self.put("config", self.secret + "\n")
        self.git("add", "config")
        # This disposable fixture deliberately commits a synthetic token, never real credentials.
        self.git("-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false",
                 "-c", "user.name=Test", "-c", "user.email=test@example.test", "commit", "-qm", "fixture")
        self.put("config", "sanitized\n")
        self.git("add", "config")
        self.assertEqual(self.hook().returncode, 0)
        result = subprocess.run(
            [BETTERLEAKS, "git", str(self.root), "--log-opts=--all --full-history --diff-merges=first-parent",
             "--validation=false", "--redact=100", "--no-banner", "--no-color"],
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(self.secret, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
