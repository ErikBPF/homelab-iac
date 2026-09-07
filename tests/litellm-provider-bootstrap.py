import importlib.util
from pathlib import Path
from unittest.mock import patch
import tempfile

path = Path(__file__).parents[1] / "components/litellm/scripts/bootstrap-provider.py"
spec = importlib.util.spec_from_file_location("bootstrap", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory() as directory:
    target = Path(directory) / ".env.sops"
    target.write_text("encrypted")
    with patch.object(module, "api", side_effect=[None, {"user_id": module.IDENTITY, "user_role": "proxy_admin", "key": "synthetic-key"}]) as api, patch.object(module, "save_credentials") as save:
        module.bootstrap("synthetic-operator", target)
        assert api.call_count == 2
        assert api.call_args.args[2] == module.REQUEST
        save.assert_called_once_with(target, "synthetic-key")
    with patch.object(module, "api", return_value={"user_info": {"user_id": module.IDENTITY}}) as api:
        try:
            module.bootstrap("synthetic-operator", target)
        except RuntimeError:
            pass
        else:
            raise AssertionError("Existing identity must not be overwritten")
        assert api.call_count == 1
    with patch.object(module, "api", side_effect=[None, {"user_id": module.IDENTITY, "user_role": "proxy_admin", "key": "synthetic-key"}, {}, {}]) as api, patch.object(module, "save_credentials", side_effect=RuntimeError("save failed")):
        try:
            module.bootstrap("synthetic-operator", target)
        except RuntimeError:
            pass
        else:
            raise AssertionError("Persistence failure must fail closed")
        assert [c.args[0] for c in api.call_args_list][-2:] == ["/key/delete", "/user/delete"]
print("PASS: bounded identity creation, duplicate refusal, failure cleanup")

with tempfile.TemporaryDirectory() as directory:
    target = Path(directory) / ".env.sops"
    target.write_bytes(b"original-ciphertext")
    plain = "KEEP_EXISTING=unchanged\n"
    expected = plain + f"LITELLM_API_BASE={module.BASE}\nLITELLM_API_KEY=synthetic-key\n"
    with patch.object(module.subprocess, "check_output", side_effect=[plain.encode(), b"new-ciphertext", expected.encode()]) as run:
        module.save_credentials(target, "synthetic-key")
        assert target.read_bytes() == b"new-ciphertext"
        assert run.call_args_list[1].kwargs["input"] == expected.encode()
        assert all("synthetic-key" not in str(c.args) for c in run.call_args_list)
        assert target.stat().st_mode & 0o777 == 0o600
    with patch.object(module.subprocess, "check_output", side_effect=[plain.encode(), b"replacement-ciphertext", b"wrong-plaintext"]):
        try:
            module.save_credentials(target, "synthetic-key")
        except RuntimeError:
            pass
        else:
            raise AssertionError("Failed verification must preserve original ciphertext")
        assert target.read_bytes() == b"new-ciphertext"
try:
    module.NoRedirect().redirect_request(None, None, 302, None, None, "https://other.example")
except RuntimeError:
    pass
else:
    raise AssertionError("Credential forwarding on redirects must be refused")
print("PASS: encrypted-only atomic storage, argv hygiene, validation, redirect refusal")
