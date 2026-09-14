#!/usr/bin/env python3
"""Offline contract for personal subscription routing and bounded key grants."""
import json
import runpy
from pathlib import Path

root = Path(__file__).resolve().parents[1]
script = runpy.run_path(str(root / 'scripts/codex-key-access.py'))
models = json.loads((root / 'components/litellm/environments/home/production/models.json').read_text())['models']
names, proposed = script['MODELS'], script['proposed']
for name in names:
    model = models[name]
    assert model['custom_llm_provider'] == 'chatgpt'
    assert model['base_model'] == name.removeprefix('codex-')
    assert model['model_api_key'] == model['model_api_base'] == ''
    assert model['mode'] == 'chat' and model['probe_skip'] is True
before = ['qwen-chat', 'apollo-qwen38-27b']
added = proposed(before, 'grant')
assert added == before + names
assert proposed(added, 'grant') == added
assert proposed(added, 'revoke') == before
assert before == ['qwen-chat', 'apollo-qwen38-27b']
for initial, action in [([], 'grant'), (['all-proxy-models'], 'grant'), (names, 'revoke'), (before, 'invalid')]:
    try:
        proposed(initial, action)
    except ValueError:
        pass
    else:
        raise AssertionError('Unsafe allowlist accepted')
print('PASS: four native OAuth routes; bounded, idempotent personal grants and rollback')
