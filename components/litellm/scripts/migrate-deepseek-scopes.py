#!/usr/bin/env python3
"""Preview existing Hermes/OpenCode key grants; --apply performs one reviewed phase."""
import argparse
import json
from pathlib import Path
import subprocess
import urllib.parse
import urllib.request

ALIASES = {'hermes-agent-20260713', 'opencode-20260713'}
OLD = {'deepseek-flash', 'deepseek-v4-flash', 'deepseek-v4-pro', 'zen-free'}
NEW = 'deepseek-v4.1-flash'
BASE = 'https://litellm.homelab.pastelariadev.com'

def proposed(models, phase):
    if not models or 'all-proxy-models' in models:
        raise ValueError('Expected an explicit bounded model allowlist')
    if phase == 'retire' and NEW not in models:
        raise ValueError('Grant the new model before retiring old grants')
    return ([m for m in models if m not in OLD] if phase == 'retire'
            else models + ([] if NEW in models else [NEW]))

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise RuntimeError('Credentialed redirects refused')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['add', 'retire', 'self-test'])
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if args.phase == 'self-test':
        before = ['deepseek-flash', 'qwen-embed', 'apollo-qwen38-27b']
        added = proposed(before, 'add')
        assert added == before + [NEW]
        assert proposed(added, 'add') == added
        assert proposed(added, 'retire') == ['qwen-embed', 'apollo-qwen38-27b', NEW]
        try:
            proposed(before, 'retire')
        except ValueError:
            pass
        else:
            raise AssertionError('Retirement must require an existing new grant')
        print('PASS: staged migration preserves unrelated grants and rejects premature retirement')
        return
    root = Path(__file__).resolve().parents[3]
    plain = subprocess.check_output(['sops', '-d', '--input-type', 'dotenv', '--output-type', 'dotenv', str(root / '.env.sops')], stderr=subprocess.DEVNULL).decode()
    values = dict(line.split('=', 1) for line in plain.splitlines() if line.startswith(('LITELLM_API_BASE=', 'LITELLM_API_KEY=')))
    if values.get('LITELLM_API_BASE') != BASE:
        raise RuntimeError('Unexpected provider API base')
    def api(path, data=None):
        req = urllib.request.Request(BASE + path, data=None if data is None else json.dumps(data).encode(), headers={'Authorization': 'Bearer ' + values['LITELLM_API_KEY'], 'Content-Type': 'application/json'})
        with urllib.request.build_opener(NoRedirect).open(req, timeout=30) as response:
            return json.load(response)
    found = {}
    page = 1
    while True:
        inventory = api(f'/key/list?page={page}&size=100')
        for key in inventory['keys']:
            path = '/key/info?key=' + urllib.parse.quote(key, safe='')
            info = api(path)['info']
            alias = info.get('key_alias')
            if alias in ALIASES:
                if alias in found:
                    raise RuntimeError('Duplicate target key alias')
                found[alias] = (key, path, info['models'])
        if page >= inventory['total_pages']:
            break
        page += 1
    if set(found) != ALIASES:
        raise RuntimeError('Target key inventory incomplete')
    changes = [(alias, key, path, before, proposed(before, args.phase)) for alias, (key, path, before) in sorted(found.items())]
    for alias, key, path, before, after in changes:
        if args.apply and before != after:
            if api(path)['info']['models'] != before:
                raise RuntimeError('Key grants changed since review')
            api('/key/update', {'key': key, 'models': after})
            if api(path)['info']['models'] != after:
                raise RuntimeError('Key grant verification failed')
        print(json.dumps({'alias': alias, 'phase': args.phase, 'applied': args.apply, 'before': before, 'after': after}))

if __name__ == '__main__':
    main()
