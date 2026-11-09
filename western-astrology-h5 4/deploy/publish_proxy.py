"""Add only this IP site to the existing Caddy gateway, with rollback backups."""
import datetime
import json
import subprocess
import sys
from pathlib import Path

import yaml


ROOT = Path('/opt/astro-life-report')
WEB = 'ipplay-web-1'
SOURCE = Path('/opt/ipplay/releases/v2026.11.01.1/deploy/server/Caddyfile')
COMPOSE = SOURCE.with_name('compose.yaml')
COMPOSE_ENV = SOURCE.parents[2] / '.env'
SHARED = ROOT / 'shared' / 'Caddyfile'
MOUNT = f'{SHARED}:/etc/caddy/Caddyfile:ro'


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def main():
    block = Path(sys.argv[1]).read_bytes()
    assert b'http://129.226.126.212 {' in block
    # The gateway is reloaded in place; existing containers are never recreated.
    before_id = run('docker', 'inspect', WEB, '--format', '{{.Id}}').strip()
    backup = ROOT / 'shared' / 'backups' / datetime.datetime.now().strftime('ingress-%Y%m%d-%H%M%S')
    backup.mkdir(parents=True, mode=0o700)
    run('docker', 'cp', f'{WEB}:/etc/caddy/Caddyfile', str(backup / 'Caddyfile.container'))
    original_source, original_compose = SOURCE.read_bytes(), COMPOSE.read_bytes()
    original_live = (backup / 'Caddyfile.container').read_bytes()
    if original_source != original_live:
        raise RuntimeError('Live gateway differs from its source; inspect before modifying it')
    (backup / 'Caddyfile.source').write_bytes(original_source)
    (backup / 'compose.yaml').write_bytes(original_compose)
    if b'http://129.226.126.212 {' in original_live:
        if len(sys.argv) != 3:
            raise RuntimeError('Updating an existing IP site requires its exact previous block')
        previous = Path(sys.argv[2]).read_bytes().strip()
        if not previous or original_live.count(previous) != 1:
            raise RuntimeError('Previous IP configuration does not match; leave the gateway unchanged')
        combined = original_live.replace(previous, block.strip(), 1)
    else:
        combined = original_live.rstrip() + b'\n\n' + block + b'\n'
    text = original_compose.decode()
    newline = '\r\n' if '\r\n' in text else '\n'
    start = text.index('\n  web:')
    # Locate service boundaries, excluding its nested properties.
    import re
    boundaries = list(re.finditer(r'(?m)^  [A-Za-z][A-Za-z0-9_-]*:\s*$', text[start + 1:]))
    assert boundaries and boundaries[0].start() == 0
    end = start + 1 + boundaries[1].start() if len(boundaries) > 1 else len(text)
    section = text[start:end]
    marker = f'    volumes:{newline}'
    assert section.count(marker) == 1
    changed = section if MOUNT in text else section.replace(marker, marker + f'      - {MOUNT}{newline}', 1)
    patched = text[:start] + changed + text[end:]
    new_yaml = yaml.safe_load(patched)
    expected = yaml.safe_load(text)
    if MOUNT not in expected['services']['web']['volumes']:
        expected['services']['web']['volumes'].insert(0, MOUNT)
    assert expected == new_yaml, 'Only the gateway config mount may change'

    candidate = backup / 'Caddyfile.candidate'
    candidate.write_bytes(combined)
    temporary = '/tmp/Caddyfile.astro-candidate'
    run('docker', 'cp', str(candidate), f'{WEB}:{temporary}')
    run('docker', 'exec', WEB, 'caddy', 'validate', '--config', temporary, '--adapter', 'caddyfile')
    try:
        SHARED.write_bytes(combined)
        SHARED.chmod(0o644)
        SOURCE.write_bytes(combined)
        COMPOSE.write_text(patched)
        run('docker', 'compose', '--env-file', str(COMPOSE_ENV), '-f', str(COMPOSE), 'config', '--quiet')
        run('docker', 'cp', str(SHARED), f'{WEB}:/etc/caddy/Caddyfile')
        run('docker', 'exec', WEB, 'caddy', 'reload', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile')
        run('curl', '--fail', '--silent', '--show-error', '--max-time', '10', '-H', 'Host: 129.226.126.212', 'http://127.0.0.1/health')
        run('curl', '--fail', '--silent', '--show-error', '--max-time', '10', '--resolve', 'ipplay.top:443:127.0.0.1', 'https://ipplay.top/')
        assert before_id == run('docker', 'inspect', WEB, '--format', '{{.Id}}').strip()
    except BaseException:
        SHARED.write_bytes(original_live)
        SOURCE.write_bytes(original_source)
        COMPOSE.write_bytes(original_compose)
        run('docker', 'cp', str(backup / 'Caddyfile.container'), f'{WEB}:/etc/caddy/Caddyfile')
        run('docker', 'exec', WEB, 'caddy', 'reload', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile')
        raise
    print(json.dumps({'published': 'http://129.226.126.212/', 'existing_domain_ok': True,
                      'gateway_container_unchanged': True, 'backup': str(backup)}))


if __name__ == '__main__':
    main()
