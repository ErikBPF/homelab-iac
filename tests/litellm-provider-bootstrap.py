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

with tempfile.TemporaryDirectory() as directory:
    target = Path(directory) / ".env.sops"
    target.write_text("encrypted")
    with patch.object(module, "read_credentials", return_value="old"), patch.object(module, "save_credentials") as save:
        def rotate_api(path, token, body=None):
            if path.startswith("/user/info"):
                return {"user_info": {"user_id": module.IDENTITY, "user_role": "proxy_admin"}}
            if path == "/key/generate":
                return {"key": "new"}
            if path == "/key/info" and token == "new":
                return {"info": {"user_id": module.IDENTITY}}
            if path == "/key/info" and token == "old":
                raise module.APIError(401)
            if path == "/key/delete":
                assert save.called, "Old key must survive until encrypted persistence"
                assert body == {"keys": ["old"]}
                return {}
            raise AssertionError(path)
        with patch.object(module, "api", side_effect=rotate_api):
            module.rotate("operator", target)
        save.assert_called_once_with(target, "new", replace_key="old")
    with patch.object(module, "read_credentials", return_value="old"), patch.object(module, "save_credentials", side_effect=RuntimeError("cannot persist")):
        responses = [{"user_info": {"user_id": module.IDENTITY, "user_role": "proxy_admin"}}, {"key": "new"}, {"info": {"user_id": module.IDENTITY}}, {}]
        with patch.object(module, "api", side_effect=responses) as api:
            try:
                module.rotate("operator", target)
            except RuntimeError:
                pass
            else:
                raise AssertionError("Failed save must fail rotation")
            assert api.call_args.args == ("/key/delete", "operator", {"keys": ["new"]})
print("PASS: replacement verified and saved before old-key revocation")

with tempfile.TemporaryDirectory() as directory:
    target = Path(directory) / ".env.sops"
    target.write_bytes(b"original")
    plain = f"KEEP=unchanged\nLITELLM_API_BASE={module.BASE}\nLITELLM_API_KEY=old\n"
    expected = plain.replace("LITELLM_API_KEY=old", "LITELLM_API_KEY=new")
    with patch.object(module.subprocess, "check_output", side_effect=[plain.encode(), b"replacement", expected.encode()]):
        module.save_credentials(target, "new", replace_key="old")
        assert target.read_bytes() == b"replacement"
    with patch.object(module.subprocess, "check_output", return_value=expected.encode()) as run:
        try:
            module.save_credentials(target, "another", replace_key="old")
        except RuntimeError:
            pass
        else:
            raise AssertionError("Stale rotation must not overwrite newer credentials")
        assert run.call_count == 1
        assert target.read_bytes() == b"replacement"
print("PASS: rotation preserves other values and refuses a stale stored key")
