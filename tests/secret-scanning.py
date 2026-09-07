#!/usr/bin/env python3
"""Exercise the real scanner using disposable history; never print findings."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="iac-secret-scan-") as directory:
    repo = Path(directory)
    env = {**os.environ, "GIT_AUTHOR_NAME": "Scanner test", "GIT_AUTHOR_EMAIL": "scanner@example.invalid",
           "GIT_COMMITTER_NAME": "Scanner test", "GIT_COMMITTER_EMAIL": "scanner@example.invalid"}

    def git(*args):
        subprocess.run(["git", *args], cwd=repo, env=env, check=True, capture_output=True)

    def scan(expected, forbidden=""):
        result = subprocess.run(["gitleaks", "git", "--redact", "--no-banner", "."],
                                cwd=repo, capture_output=True, text=True)
        assert result.returncode == expected, "unexpected scanner exit status"
        assert not forbidden or forbidden not in result.stdout + result.stderr, "unredacted finding"

    git("init", "-q")
    (repo / ".gitleaksignore").write_bytes((root / ".gitleaksignore").read_bytes())
    # Real tracked ciphertext, copied unchanged. No decryption or report artifact.
    ciphertext = (root / ".env.sops").read_bytes()
    (repo / ".env.sops").write_bytes(ciphertext)
    git("add", ".env.sops")
    git("commit", "-qm", "encrypted configuration")
    scan(0)
    assert (repo / ".env.sops").read_bytes() == ciphertext
    # An old exact fingerprint must not exempt the same value in a new commit.
    fixture = repo / "tests/fixtures/adguard-config/main.tf"
    fixture.parent.mkdir(parents=True)
    fixture.write_bytes((root / "tests/fixtures/adguard-config/main.tf").read_bytes())
    git("add", "tests")
    git("commit", "-qm", "repeat historical fixture in new commit")
    scan(1)
    git("reset", "--hard", "HEAD~1")
    token = "ghp_" + "Ab1Cd2Ef3Gh4Ij5Kl6Mn7Op8Qr9St0Uv1Wx2"
    (repo / "leak.txt").write_text("github_token=" + token + "\n")
    git("add", "leak.txt")
    git("commit", "-qm", "synthetic leak")
    scan(1, token)
    git("rm", "-q", "leak.txt")
    git("commit", "-qm", "remove synthetic leak")
    scan(1, token)
print("Secret scanning: ciphertext, leak rejection, redaction, retained history passed")
