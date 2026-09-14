#!/usr/bin/env python3
"""Grant/revoke personal Codex routes inside LiteLLM; never rotate credentials."""
import json
import os
import re
import sys
import urllib.request

MODELS = ['codex-' + base for base in (
    'gpt-6-astra', 'gpt-5.6-luna', 'gpt-5.6-sol', 'gpt-5.6-terra',
)]


def proposed(models, action):
    if action not in ('grant', 'revoke'):
        raise ValueError('Expected grant or revoke')
    if not models or 'all-proxy-models' in models:
        raise ValueError('Expected bounded personal model access')
    result = (models + [name for name in MODELS if name not in models]
              if action == 'grant' else [name for name in models if name not in MODELS])
    if not result:
        raise ValueError('Refusing empty allowlist: LiteLLM treats it as unrestricted')
    return result


def request(path, payload=None):
    req = urllib.request.Request('http://127.0.0.1:4000' + path,
        headers={'Authorization': 'Bearer ' + os.environ['LITELLM_MASTER_KEY'],
                 'Content-Type': 'application/json'},
        data=None if payload is None else json.dumps(payload).encode())
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def main(action, fingerprint):
    if not re.fullmatch('[0-9a-f]{64}', fingerprint):
        raise ValueError('Expected SHA256 key fingerprint')
    path = '/key/info?key=' + fingerprint
    info = request(path)['info']
    if info['key_alias'] != 'opencode-20260713':
        raise ValueError('Unexpected personal key')
    before = info['models']
    after = proposed(before, action)
    if before != after:
        if request(path)['info']['models'] != before:
            raise ValueError('Key grants changed during review')
        request('/key/update', {'key': fingerprint, 'models': after})
    if request(path)['info']['models'] != after:
        raise ValueError('Key grant verification failed')
    print(json.dumps({'action': action, 'key_alias': info['key_alias'], 'models': after}))


if __name__ == '__main__':
    main(*sys.argv[1:])
