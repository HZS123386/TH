"""Publish landing ingress routes with rollback; preserve existing domain sites."""
import argparse
import datetime
import hashlib
import json
import re
import subprocess
from pathlib import Path

import yaml


ROOT = Path('/opt/astro-life-report')
WEB = 'ipplay-web-1'
SOURCE = Path('/opt/ipplay/current/deploy/server/Caddyfile').resolve()
COMPOSE = SOURCE.with_name('compose.yaml')
COMPOSE_ENV = SOURCE.parents[2] / '.env'
SHARED = ROOT / 'shared' / 'Caddyfile'
MOUNT = f'{SHARED}:/etc/caddy/Caddyfile:ro'


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def add_domain_routes(config: bytes, routes: bytes) -> bytes:
    """Place the landing routes inside the original public domain site."""
    newline = b'\r\n' if b'\r\n' in config else b'\n'
    routes = routes.replace(b'\r\n', b'\n').rstrip().replace(b'\n', newline) + newline
    headers = list(re.finditer(
        rb'(?m)^\{\$APP_DOMAIN:ipplay\.top\}(?:, www\.\{\$APP_DOMAIN:ipplay\.top\})? \{\r?\n', config))
    if len(headers) != 1:
        raise RuntimeError('Expected exactly one original public domain site')
    start = headers[0].end()
    end = config.index(b'\n}', start)
    site = config[start:end]
    routes = routes.strip(b'\r\n')
    if b'# BEGIN FATE landing routes' in site:
        if site.count(routes) != 1:
            raise RuntimeError('Existing domain landing routes differ; inspect before updating')
        return config
    anchor = b'    handle /api/v1/* {'
    if site.count(anchor) != 1:
        raise RuntimeError('Expected the original API route in the public domain site')
    changed = site.replace(anchor, routes + newline + anchor, 1)
    return config[:start] + changed + config[end:]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('ip_routes', type=Path)
    parser.add_argument('previous_ip_routes', type=Path, nargs='?')
    parser.add_argument('--domain-routes', type=Path)
    parser.add_argument('--release')
    args = parser.parse_args()
    if args.domain_routes and not re.fullmatch(r'v\d{4}\.\d{2}\.\d{2}\.[1-9]\d*', args.release or ''):
        parser.error('Domain configuration updates require a new vYYYY.MM.DD.N release')
    block = args.ip_routes.read_bytes()
    assert b'http://129.226.126.212 {' in block
    # The gateway is reloaded in place; existing containers are never recreated.
    before_id = run('docker', 'inspect', WEB, '--format', '{{.Id}}').strip()
    backup = (Path('/opt/ipplay/shared/config-releases') / args.release if args.domain_routes else
              ROOT / 'shared' / 'backups' / datetime.datetime.now().strftime('ingress-%Y%m%d-%H%M%S'))
    backup.mkdir(parents=True, mode=0o700, exist_ok=False)
    run('docker', 'cp', f'{WEB}:/etc/caddy/Caddyfile', str(backup / 'Caddyfile.container'))
    original_source, original_compose = SOURCE.read_bytes(), COMPOSE.read_bytes()
    original_live = (backup / 'Caddyfile.container').read_bytes()
    if original_source != original_live:
        raise RuntimeError('Live gateway differs from its source; inspect before modifying it')
    (backup / 'Caddyfile.source').write_bytes(original_source)
    (backup / 'compose.yaml').write_bytes(original_compose)
    # Caddy's global options must precede site blocks. Do not replace unrelated
    # global settings: stop for inspection if this gateway acquires any others.
    marker = b'# Shared routes keep the existing HTTP entry available for credential migration.'
    global_options = b''
    if block.startswith(b'{\n'):
        offset = block.index(marker)
        global_options, block = block[:offset], block[offset:]
        if b'default_sni 129.226.126.212' not in global_options:
            raise RuntimeError('Unexpected global options')
        if original_live.startswith(global_options):
            original_live_sites = original_live[len(global_options):]
        elif original_live.lstrip().startswith(b'{') and not original_live.lstrip().startswith(b'{$'):
            raise RuntimeError('Inspect existing global options before changing them')
        else:
            original_live_sites = original_live
    else:
        original_live_sites = original_live
    if b'http://129.226.126.212 {' in original_live:
        if args.previous_ip_routes is None:
            raise RuntimeError('Updating an existing IP site requires its exact previous block')
        previous = args.previous_ip_routes.read_bytes().strip()
        if global_options and previous.startswith(global_options):
            previous = previous[len(global_options):].strip()
        if not previous or original_live_sites.count(previous) != 1:
            raise RuntimeError('Previous IP configuration does not match; leave the gateway unchanged')
        combined = global_options + original_live_sites.replace(previous, block.strip(), 1)
    else:
        combined = global_options + original_live_sites.rstrip() + b'\n\n' + block + b'\n'
    if args.domain_routes:
        combined = add_domain_routes(combined, args.domain_routes.read_bytes())
    text = original_compose.decode()
    newline = '\r\n' if '\r\n' in text else '\n'
    start = text.index('\n  web:')
    # Locate service boundaries, excluding its nested properties.
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
    releases_file = SOURCE.with_name('releases.json')
    receipt = Path('/opt/ipplay/shared/releases') / f'{args.release}.json'
    release_history = None
    if args.domain_routes:
        if receipt.exists():
            raise RuntimeError('Configuration release receipt already exists')
        release_history = json.loads(releases_file.read_text())
        if any(item['version'] == args.release for item in release_history['releases']):
            raise RuntimeError('Configuration release version already exists')
        (backup / 'releases.before.json').write_bytes(releases_file.read_bytes())

    candidate = backup / 'Caddyfile.candidate'
    candidate.write_bytes(combined)
    temporary = '/tmp/Caddyfile.astro-candidate'
    run('docker', 'cp', str(candidate), f'{WEB}:{temporary}')
    run('docker', 'exec', WEB, 'caddy', 'validate', '--config', temporary, '--adapter', 'caddyfile')
    result = {'published': 'https://ipplay.top/thai-landing/' if args.domain_routes else 'https://129.226.126.212/',
              'existing_domain_ok': True, 'gateway_container_unchanged': True, 'backup': str(backup)}
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
        if args.domain_routes:
            html = run('curl', '--fail', '--silent', '--show-error', '--max-time', '15', '--resolve',
                       'ipplay.top:443:127.0.0.1', 'https://ipplay.top/thai-landing/')
            assert '<base href="/thai-landing/">' in html, 'Landing domain did not reach Flutter'
        assert before_id == run('docker', 'inspect', WEB, '--format', '{{.Id}}').strip()
        if args.domain_routes:
            result.update(version=args.release, date=args.release[1:11].replace('.', '-'),
                          recordType='configuration-update', status='deployed',
                          deployedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                          scope='fate-landing-domain-routes-only', productionBase=SOURCE.parents[2].name,
                          applicationImagesUnchanged=True, databaseMigration=False,
                          previousConfigSha256=hashlib.sha256(original_source).hexdigest(),
                          activeConfigSha256=hashlib.sha256(combined).hexdigest(),
                          rollback={'baseRelease': SOURCE.parents[2].name, 'gatewayConfig': str(backup / 'Caddyfile.source')})
            receipt.parent.mkdir(parents=True, exist_ok=True)
            with receipt.open('x') as output:
                json.dump(result, output, ensure_ascii=False, indent=2)
            release_history['releases'].insert(0, {**result, 'evidence': str(receipt)})
            releases_file.write_text(json.dumps(release_history, ensure_ascii=False, indent=2) + '\n')
            (backup / 'deployment.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    except BaseException:
        SHARED.write_bytes(original_live)
        SOURCE.write_bytes(original_source)
        COMPOSE.write_bytes(original_compose)
        run('docker', 'cp', str(backup / 'Caddyfile.container'), f'{WEB}:/etc/caddy/Caddyfile')
        run('docker', 'exec', WEB, 'caddy', 'reload', '--config', '/etc/caddy/Caddyfile', '--adapter', 'caddyfile')
        if release_history is not None:
            releases_file.write_bytes((backup / 'releases.before.json').read_bytes())
            receipt.unlink(missing_ok=True)
        raise
    print(json.dumps(result))


if __name__ == '__main__':
    main()
