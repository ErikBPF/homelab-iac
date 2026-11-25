#!/usr/bin/env python3
"""Full GLM 5.3 routing and bounded personal access; no live credentials."""
import json
import runpy
from pathlib import Path

root = Path(__file__).resolve().parents[1]
models = json.loads((root / 'components/litellm/environments/home/production/models.json').read_text())['models']
assert 'glm-5.3' in models, 'Full GLM 5.3 route is missing'
model = models['glm-5.3']
assert model['base_model'] == 'glm-5.3'
assert model['custom_llm_provider'] == 'openai'
assert model['model_api_base'] == 'https://opencode.ai/inference/go/openai/v1'
assert model['model_api_key'] == 'os.environ/OPENCODE_GO_KEY'
assert model['context_limit'] == 1000000
assert model['output_limit'] == 131072
assert model['input_cost_per_million_tokens'] == 1.4
assert model['output_cost_per_million_tokens'] == 4.4
assert model['cache_read_input_cost_per_million_tokens'] == 0.26
assert model['supports_reasoning'] and model['supports_tools']
assert model['probe_skip'] is True
assert 'glm-5.3-flash' in models, 'Other clients retain the Flash route'
allowlists = json.loads((root / 'tests/fixtures/litellm-discovery-allowlists.json').read_text())
assert 'glm-5.3' in allowlists['opencode']
assert all('glm-5.3' not in value for key, value in allowlists.items() if key != 'opencode')

helper = runpy.run_path(str(root / 'scripts/codex-key-access.py'))
proposed = helper['proposed']
before = ['deepseek-v4.1-flash', *helper['MODELS']]
after = proposed(before, 'grant', 'glm-5.3')
assert after == [*before, 'glm-5.3']
assert proposed(after, 'grant', 'glm-5.3') == after
assert proposed(after, 'revoke', 'glm-5.3') == before
assert before == ['deepseek-v4.1-flash', *helper['MODELS']]
for models, action, scope in [([], 'grant', 'glm-5.3'), (['all-proxy-models'], 'grant', 'glm-5.3'),
                              (['glm-5.3'], 'revoke', 'glm-5.3'), (before, 'grant', 'other')]:
    try:
        proposed(models, action, scope)
    except ValueError:
        pass
    else:
        raise AssertionError('Unsafe grant accepted')
print('PASS: full GLM 5.3 route; personal-only, bounded, idempotent grant and rollback')
