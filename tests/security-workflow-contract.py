#!/usr/bin/env python3
"""Verify workflow wiring, synthetic scanner outcomes and value-free notifications."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/ci.yml"
JOB = "secret-scan"


def notification_runs(condition, event, outcome, ref="refs/heads/main"):
    values = {"github.event_name": event, "steps.gitleaks.outcome": outcome, "github.ref": ref}
    terms = condition.split(" && ")
    assert terms[0] == "always()", "failure notifications need an explicit status function"
    result = True
    for term in terms[1:]:
        match = re.fullmatch(r"([a-z_.]+) (==|!=) '([a-z0-9_/-]+)'", term)
        assert match and match[1] in values, "unsupported notification expression"
        equal = values[match[1]].casefold() == match[3].casefold()
        result = result and (equal if match[2] == "==" else not equal)
    return result


class SecurityWorkflow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text()
        cls.job = re.search(
            rf"(?ms)^  {re.escape(JOB)}:\n(.*?)(?=^  [a-z][a-z0-9_-]*:|\Z)", cls.source
        )[1]
        marker = "      - name: Notify security channel\n"
        cls.notice = cls.job.split(marker, 1)[1] if marker in cls.job else ""
        match = re.search(r"(?m)^        if: (.+)$", cls.notice)
        cls.condition = match[1] if match else ""
        cls.script = textwrap.dedent(cls.notice.split("        run: |\n", 1)[1]) if "        run: |\n" in cls.notice else ""

    def test_automatic_unprivileged_full_history_scanning(self):
        trigger = re.search(r"(?ms)^on:\n(.*?)(?=^[a-z])", self.source)[1]
        events = set(re.findall(r"(?m)^  ([a-z_]+):", trigger))
        self.assertEqual(events, {"push", "pull_request", "workflow_dispatch"})
        self.assertRegex(trigger, r"(?m)^    branches: \[main\]$")
        self.assertNotIn("paths:", trigger)
        self.assertIn("contents: read", self.source)
        self.assertNotRegex(self.source, r"(?:contents|pull-requests|id-token): write")
        self.assertIn("runs-on: ubuntu-latest", self.job)
        self.assertIn("fetch-depth: 0", self.job)
        self.assertIn("persist-credentials: false", self.job)
        self.assertNotIn("continue-on-error", self.job)
        self.assertIn("      - id: gitleaks\n", self.job)
        self.assertIn("sha256sum --check", self.job)
        self.assertIn('gitleaks git --log-opts=HEAD --redact --no-banner --ignore-gitleaks-allow --config "$RUNNER_TEMP/gitleaks.toml" --gitleaks-ignore-path "$RUNNER_TEMP/gitleaks.ignore" .', self.job)
        self.assertIn("SCAN_POLICY_REF: ${{ github.event.pull_request.base.sha || github.sha }}", self.job)
        self.assertIn('git show "${SCAN_POLICY_REF}:.gitleaksignore"', self.job)
        self.assertIn('git cat-file -e "${SCAN_POLICY_REF}^{commit}"', self.job)
        self.assertIn("useDefault = true", self.job)
        self.assertIn('cp --remove-destination "$RUNNER_TEMP/gitleaks.ignore" .gitleaksignore', self.job)
        self.assertNotIn("GITHUB_TOKEN:", self.job)
        self.assertNotIn("upload-artifact", self.job)
        self.assertLess(self.job.index("          gitleaks git "),
                        self.job.index("          python3 tests/"))
        for action in re.findall(r"uses: (\S+)", self.source):
            self.assertRegex(action, r"@[0-9a-f]{40}$")

    def test_contract_runs_after_failed_scan_without_masking_either_result(self):
        scan_step = self.job.split("      - id: gitleaks\n", 1)[1].split("\n      - ", 1)[0]
        scan_script = textwrap.dedent(scan_step.split("        run: |\n", 1)[1])
        scan_tail = scan_script.split("# Scan before executing code from the scanned revision.\n", 1)[1]
        cases = ((name, scan, result) for name in ("Verify workflow contract", "Verify scanner contract")
                 for scan, result in ((1, 0), (0, 1), (0, 0), (1, 1)))
        for name, scan_exit, contract_exit in cases:
            contract = re.search(rf"(?ms)^      - name: {name}\n(.*?)(?=^      - |\Z)", self.job)
            with self.subTest(step=name, scan=scan_exit, contract=contract_exit), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                verified = root / "gitleaks-bin"
                verified.mkdir()
                stub_bin = root / "stubs"
                stub_bin.mkdir()
                scanner = verified / "gitleaks"
                scanner.write_text('#!/bin/sh\nprintf "scan\\n" >> "$S7_EVENTS"\nexit "$S7_SCAN_EXIT"\n')
                scanner.chmod(0o700)
                python = stub_bin / "python3"
                python.write_text('#!/bin/sh\n[ "$(command -v gitleaks)" = "$RUNNER_TEMP/gitleaks-bin/gitleaks" ] || exit 97\nprintf "contract\\n" >> "$S7_EVENTS"\nexit "$S7_CONTRACT_EXIT"\n')
                python.chmod(0o700)
                output = root / "outputs"
                output.touch()
                env = {"PATH":str(stub_bin)+os.pathsep+os.environ["PATH"],
                       "RUNNER_TEMP":directory, "GITHUB_OUTPUT":str(output),
                       "S7_EVENTS":str(root / "events"), "S7_SCAN_EXIT":str(scan_exit),
                       "S7_CONTRACT_EXIT":str(contract_exit)}
                scan = subprocess.run(["bash", "-euo", "pipefail", "-c", scan_tail],
                                      env={**env, "PATH":str(verified)+os.pathsep+env["PATH"]},
                                      cwd=root, capture_output=True)
                verification = None
                if contract and "scan_completed=true" in output.read_text().splitlines():
                    self.assertIn("if: always() && !cancelled() && steps.gitleaks.outputs.scan_completed == 'true'", contract[1])
                    script = textwrap.dedent(contract[1].split("        run: |\n", 1)[1])
                    verification = subprocess.run(["bash", "-euo", "pipefail", "-c", script],
                                                  env=env, cwd=root, capture_output=True)
                self.assertEqual((root / "events").read_text().splitlines(), ["scan", "contract"],
                                 "contract must run after a failed scan")
                self.assertEqual(scan.returncode, scan_exit, "scanner failure was masked or mixed with contract status")
                self.assertIsNotNone(verification, "contract needs an independent workflow step")
                self.assertEqual(verification.returncode, contract_exit, "contract result was masked")

    def test_manual_dispatch_requires_reviewed_main(self):
        run = self.job.split("        run: |\n", 1)[1]
        guard = textwrap.dedent(run.split("          git cat-file -e", 1)[0])
        for event, ref, allowed in (("push","refs/heads/main",True),
                                    ("pull_request","refs/pull/1/merge",True),
                                    ("workflow_dispatch","refs/heads/main",True),
                                    ("workflow_dispatch","refs/heads/feature",False),
                                    ("workflow_dispatch","refs/tags/main",False)):
            env = {"PATH":os.environ["PATH"], "GITHUB_EVENT_NAME":event, "GITHUB_REF":ref}
            result = subprocess.run(["bash","-euo","pipefail","-c",guard], env=env, capture_output=True)
            self.assertEqual(result.returncode == 0, allowed, "unreviewed dispatch policy accepted")

    def test_trusted_failure_and_fork_notification_fixtures(self):
        self.assertTrue(self.condition, "security failure notification missing")
        for event in ("push", "pull_request", "workflow_dispatch"):
            for outcome in ("failure", "success", "skipped", "cancelled"):
                self.assertEqual(notification_runs(self.condition, event, outcome),
                                 outcome == "failure" and event != "pull_request")
        self.assertFalse(notification_runs(self.condition, "workflow_dispatch", "failure", "refs/heads/feature"))
        self.assertFalse(notification_runs(self.condition, "workflow_dispatch", "failure", "refs/tags/main"))
        # A fork PR has the same event and must never enter the webhook step.
        self.assertFalse(notification_runs(self.condition, "pull_request", "failure"))
        with self.assertRaises(AssertionError):
            notification_runs("success() && unknown", "push", "failure")

    def test_declared_public_scanner_merge_gates(self):
        config = (ROOT / "github/repos/terragrunt.hcl").read_text()
        for repo, checks in (("homelab-iac", ("lint", "secret-scan")), ("homelab-gitops", ("secrets",))):
            block = re.search(rf"(?ms)^    {re.escape(repo)} = \{{(.*?)^    \}}", config)[1]
            self.assertRegex(block, r"protect_main\s*=\s*true")
            required = re.search(r"required_checks\s*=\s*\[([^]]+)\]", block)
            self.assertIsNotNone(required, f"{repo}: scanner gate missing")
            self.assertTrue(set(checks).issubset(re.findall(r'"([^\"]+)"', required[1])))
        private = re.search(r"(?ms)^    servarr = \{(.*?)^    \}", config)[1]
        self.assertRegex(private, r'visibility\s*=\s*"private"')
        self.assertRegex(private, r'protect_main\s*=\s*false')

    def test_actual_notification_script_and_missing_webhook(self):
        self.assertTrue(self.script, "security notification script missing")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stub = root / "curl"
            stub.write_text("#!/usr/bin/env python3\nimport os,sys\nfrom pathlib import Path\nPath(os.environ['S7_CALLS']).write_text(sys.stdin.read())\n")
            stub.chmod(0o755)
            env = {"PATH": str(root) + os.pathsep + os.environ["PATH"], "HOME": directory,
                   "S7_CALLS": str(root / "calls"), "CLEYTIN_USER_ID": "1532710143517659356",
                   "GITHUB_REPOSITORY": "fixture/repository", "GITHUB_REF_NAME": "main", "GITHUB_REF": "refs/heads/main",
                   "GITHUB_SERVER_URL": "https://github.invalid", "GITHUB_RUN_ID": "1"}
            for webhook in ("", "https://discord.invalid/synthetic"):
                env["WEBHOOK"] = webhook
                result = subprocess.run(["bash", "-euo", "pipefail", "-c", self.script],
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, "notification script failed")
                self.assertEqual((root / "calls").exists(), bool(webhook))
            payload = json.loads((root / "calls").read_text())
            self.assertEqual(payload["allowed_mentions"], {"users": [env["CLEYTIN_USER_ID"]]})
            self.assertIn("findings withheld", payload["embeds"][0]["description"])
            for ref in ("refs/heads/feature", "refs/heads/Main", "refs/tags/main"):
                (root / "calls").unlink(missing_ok=True)
                subprocess.run(["bash", "-euo", "pipefail", "-c", self.script],
                               env={**env,"GITHUB_REF":ref}, capture_output=True, check=True)
                self.assertFalse((root / "calls").exists(), "unreviewed ref notified")

    def test_real_scanner_rejects_new_and_removed_synthetic_secret(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {**os.environ, "GIT_AUTHOR_NAME": "Security fixture",
                   "GIT_AUTHOR_EMAIL": "fixture@example.invalid", "GIT_COMMITTER_NAME": "Security fixture",
                   "GIT_COMMITTER_EMAIL": "fixture@example.invalid", "GIT_CONFIG_GLOBAL": "/dev/null",
                   "GIT_CONFIG_NOSYSTEM": "1"}
            def git(*args):
                subprocess.run(["git", *args], cwd=root, env=env, check=True, capture_output=True)
            def scan(expected, secret=""):
                # Mirror workflow replacement of the implicitly loaded source ignore file.
                subprocess.run(["cp", "--remove-destination", str(root / ".git/trusted.ignore"),
                                str(root / ".gitleaksignore")], check=True, capture_output=True)
                result = subprocess.run(["gitleaks", "git", "--log-opts=HEAD", "--redact", "--no-banner", "--ignore-gitleaks-allow",
                                         "--config", str(root / ".git/trusted.toml"),
                                         "--gitleaks-ignore-path", str(root / ".git/trusted.ignore"), "."],
                                        cwd=root, env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, "unexpected real scanner result")
                self.assertTrue(not secret or secret not in result.stdout + result.stderr, "scanner failed to redact canary")
            git("init", "-q")
            (root / ".git/trusted.toml").write_text("[extend]\nuseDefault = true\n")
            (root / ".git/trusted.ignore").write_text("")
            (root / "clean.txt").write_text("no credentials\n")
            git("add", "."); git("commit", "-qm", "clean fixture"); scan(0)
            token = "ghp_" + "Ab1Cd2Ef3Gh4Ij5Kl6Mn7Op8Qr9St0Uv1Wx2"
            (root / "leak.txt").write_text("github_token=" + token + "\n")
            git("add", "."); git("commit", "-qm", "synthetic fixture"); scan(1, token)
            # The scanned revision must not suppress its own credential finding.
            head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
            (root / ".gitleaks.toml").write_text('[extend]\nuseDefault = true\n[allowlist]\npaths = [".*"]\n')
            (root / ".gitleaksignore").write_text(f"{head}:leak.txt:github-pat:1\n")
            git("add", "."); git("commit", "-qm", "untrusted suppression fixture"); scan(1, token)
            (root / ".gitleaksignore").unlink()
            (root / ".gitleaksignore").symlink_to(root / ".git/trusted.toml")
            git("add", ".gitleaksignore"); git("commit", "-qm", "untrusted policy symlink"); scan(1, token)
            self.assertEqual((root / ".git/trusted.toml").read_text(), "[extend]\nuseDefault = true\n")
            (root / "leak.txt").write_text("github_token=" + token + " # gitleaks:allow\n")
            git("add", "leak.txt"); git("commit", "-qm", "untrusted inline suppression"); scan(1, token)
            git("rm", "leak.txt"); git("commit", "-qm", "remove fixture"); scan(1, token)
        # This verified public object identifier must survive a squash commit.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            env = {**os.environ, "GIT_AUTHOR_NAME":"Security fixture", "GIT_AUTHOR_EMAIL":"fixture@example.invalid",
                   "GIT_COMMITTER_NAME":"Security fixture", "GIT_COMMITTER_EMAIL":"fixture@example.invalid"}
            subprocess.run(["git","init","-q"],cwd=root,env=env,check=True,capture_output=True)
            (root/"main.tf").write_text('signing_key = "a2f6e3ea-c944-4328-8ffd-e0a2b2beb529"\n')
            subprocess.run(["git","add","."],cwd=root,env=env,check=True,capture_output=True)
            subprocess.run(["git","commit","-qm","squashed public object reference"],cwd=root,env=env,check=True,capture_output=True)
            policy = re.search(r"(?ms)cat > \"\$RUNNER_TEMP/gitleaks.toml\" <<'TOML'\n(.*?)^          TOML$", self.job)
            self.assertIsNotNone(policy, "explicit reviewed object-ID policy missing")
            (root/".git/trusted.toml").write_text(textwrap.dedent(policy[1]))
            result=subprocess.run(["gitleaks","git","--redact","--no-banner","--ignore-gitleaks-allow","--config",str(root/".git/trusted.toml"),"."],cwd=root,env=env,capture_output=True)
            self.assertEqual(result.returncode,0,"squashed public object UUID falsely rejected")
            # Derive the unlisted neighbor; never introduce another literal scanner canary.
            unlisted_id = 'b' + 'a2f6e3ea-c944-4328-8ffd-e0a2b2beb529'[1:]
            (root/"other.tf").write_text('signing_key = "' + unlisted_id + '"\n')
            subprocess.run(["git","add","."],cwd=root,env=env,check=True,capture_output=True)
            subprocess.run(["git","commit","-qm","unlisted credential-shaped UUID"],cwd=root,env=env,check=True,capture_output=True)
            result=subprocess.run(["gitleaks","git","--redact","--no-banner","--ignore-gitleaks-allow","--config",str(root/".git/trusted.toml"),"."],cwd=root,env=env,capture_output=True)
            self.assertEqual(result.returncode,1,"object exception incorrectly exempts other values")



if __name__ == "__main__":
    unittest.main()
