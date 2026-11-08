#!/usr/bin/env python3
"""Exercise the guard against a real temporary Git index."""
import pathlib
import subprocess
import tempfile
import unittest

GUARD = pathlib.Path(__file__).with_name("check-publication.py").resolve()


class PublicationTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
