"""Package the existing applications without local users or build-time secrets."""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import tarfile
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TH = ROOT.parent / 'TH'
PRIVATE = ROOT.parent / 'output' / 'deploy'
SKIP = {'__pycache__', '.pytest_cache', '.ruff_cache', 'tests', 'node_modules', '.git'}
SUNLANDS_KEYS = (
    'SUNLANDS_BASE_URL', 'SUNLANDS_APP_KEY', 'SUNLANDS_APP_SECRET', 'SUNLANDS_CHANNEL_CODE',
    'SUNLANDS_ITEM_NO', 'SUNLANDS_PRODUCT_NO', 'SUNLANDS_ITEM_TITLE', 'SUNLANDS_ORDER_MOBILE',
    'SUNLANDS_ORDER_NATION_CODE', 'SUNLANDS_PROVINCE_ID', 'SUNLANDS_MERCHANT_NOTIFY_URI',
    'SUNLANDS_H5_RETURN_URL',
)


def copy_tree(source: Path, target: Path):
    shutil.copytree(source, target, symlinks=False,
                    ignore=lambda _directory, names: [name for name in names if name in SKIP or name.endswith(('.pyc', '.pyo'))])


def prepare(release: Path, version: str):
    database_url = os.environ.get('FATE_DEPLOY_DATABASE_URL', '')
    if not database_url.startswith(('postgresql://', 'postgres://')) or any(char in database_url for char in '\r\n'):
        raise SystemExit('Set FATE_DEPLOY_DATABASE_URL to the migrated server PostgreSQL database.')
    context = release / 'context'
    context.mkdir(parents=True)
    for name in ('Dockerfile', 'compose.yaml', 'Caddyfile.ip', 'Caddyfile.domain', 'Caddyfile.fatehoro'):
        shutil.copy2(ROOT / 'deploy' / name, context / name)
    copy_tree(TH / 'backend', context / 'TH' / 'backend')
    copy_tree(TH / 'h5_admin', context / 'TH' / 'h5_admin')
    copy_tree(TH / 'scripts', context / 'TH' / 'scripts')
    for directory in ('content', 'locales', 'data'):
        copy_tree(TH / 'src' / directory, context / 'TH' / 'src' / directory)
    shutil.copy2(TH / 'package.json', context / 'TH' / 'package.json')
    copy_tree(TH / 'node_modules' / 'thai-astrology', context / 'TH' / 'node_modules' / 'thai-astrology')
    copy_tree(ROOT / 'site', context / 'western-astrology-h5 4' / 'site')

    env = {}
    for line in (TH / '.env').read_text(encoding='utf-8-sig').splitlines():
        if not line.strip() or line.lstrip().startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        env[key.strip()] = value.strip().strip('"').strip("'")
    if not all(env.get(key) for key in ('QWEN_API_KEY', 'QWEN_BASE_URL', 'QWEN_MODEL')):
        raise RuntimeError('The report model server configuration is incomplete')
    config = {
        'APP_ENV': 'production',
        'DATABASE_URL': database_url,
        'DEFAULT_PROVIDER': 'mock',
        'SESSION_HOURS': '168',
        'FORTUNE_PROVIDER': env.get('FORTUNE_PROVIDER', 'qwen'),
        **{key: env[key] for key in ('QWEN_API_KEY', 'QWEN_BASE_URL', 'QWEN_MODEL')},
        'BAZI_REPORT_PROVIDER': env.get('BAZI_REPORT_PROVIDER', 'qwen'),
        'BAZI_REPORTS_PER_MINUTE': env.get('BAZI_REPORTS_PER_MINUTE', '0'),
        'BAZI_REPORTS_PER_DAY': env.get('BAZI_REPORTS_PER_DAY', '0'),
        'ROXY_ENABLED': env.get('ROXY_ENABLED', 'false'),
        'BAZI_PROVIDER': env.get('BAZI_PROVIDER', 'github'),
        'LIFE_ASTROLOGY_PROVIDER': env.get('LIFE_ASTROLOGY_PROVIDER', 'thai'),
        'THAI_LANDING_DIR': '/app/western-astrology-h5 4/site',
        'FATE_SUPPORT_EMAIL': env.get('FATE_SUPPORT_EMAIL', ''),
    }
    # Carry the configured writers and live checkout separately from the application archive.
    optional = [
        'FORTUNE_FALLBACK_PROVIDER', 'WESTERN_REPORT_PROVIDER', 'WESTERN_REPORT_MODEL',
        'WESTERN_REVIEW_ENABLED', 'WESTERN_REVIEW_PROVIDER', 'WESTERN_REVIEW_MODEL',
        'WESTERN_REVIEW_FALLBACK_PROVIDER', 'WESTERN_REVIEW_FALLBACK_MODEL',
        'SUNLANDS_ORDER_ONLY', *SUNLANDS_KEYS,
    ]
    for provider in ('OPENAI', 'QWEN', 'KIMI', 'DEEPSEEK'):
        optional.extend(f'{provider}_{suffix}' for suffix in (
            'API_KEY', 'BASE_URL', 'MODEL', 'PROXY_URL', 'REASONING_EFFORT'))
    config.update({key: env[key] for key in optional if env.get(key)})
    payment = {key: os.environ.get(key, env.get(key, '')) for key in SUNLANDS_KEYS
               if key in os.environ or key in env}
    config.update(payment)
    config['SUNLANDS_ORDER_ONLY'] = os.environ.get('SUNLANDS_ORDER_ONLY', config.get('SUNLANDS_ORDER_ONLY', ''))
    if config.get('SUNLANDS_ORDER_ONLY', '').lower() != 'true':
        raise RuntimeError('Paid H5 requires SUNLANDS_ORDER_ONLY=true.')
    if config.get('SUNLANDS_BASE_URL', 'https://api-prod.sunlands.com') != 'https://api-prod.sunlands.com':
        raise RuntimeError('Production Sunlands requires the live gateway')
    required = ('SUNLANDS_APP_SECRET', 'SUNLANDS_ORDER_MOBILE', 'SUNLANDS_PROVINCE_ID', 'SUNLANDS_H5_RETURN_URL')
    missing = [key for key in required if not config.get(key, '').strip()]
    if missing:
        raise RuntimeError(f'Missing Sunlands deploy settings: {", ".join(missing)}')
    config['SUNLANDS_ORDER_ONLY'] = 'true'
    if any(char in value for value in config.values() for char in '\r\n\0'):
        raise RuntimeError('Runtime settings must use single-line values')
    if config['ROXY_ENABLED'].lower() == 'true':
        if not env.get('ROXY_API_KEY'):
            raise RuntimeError('Roxy is enabled but its server-side key is missing')
        config['ROXY_API_KEY'] = env['ROXY_API_KEY']
    if config['LIFE_ASTROLOGY_PROVIDER'] == 'roxy' and config['ROXY_ENABLED'].lower() != 'true':
        raise RuntimeError('Western landing reports require Roxy to be enabled')
    # This file is transferred separately and never enters the Docker build context.
    runtime = ''.join(f'{key}={value}\n' for key, value in config.items() if key not in payment)
    for key, value in payment.items():
        literal = json.dumps(value, ensure_ascii=False).replace('$', '$$')
        runtime += f'{key}={literal}\n'
    (release / 'runtime.env').write_text(runtime, encoding='utf-8', newline='\n')
    (context / '.dockerignore').write_text('*.env\n.env*\ndata/\n*.pem\n*.key\n', encoding='utf-8')

    sensitive = [database_url, *(value for key, value in (*env.items(), *payment.items()) if value and
                                any(part in key for part in ('API_KEY', 'SECRET', 'PASSWORD', 'TOKEN', 'DATABASE_URL', 'SUNLANDS_ORDER_MOBILE')))]
    manifest = []
    for path in sorted(context.rglob('*')):
        if not path.is_file():
            continue
        body = path.read_bytes()
        if any(secret.encode() in body for secret in sensitive):
            raise RuntimeError('A local secret entered the build context')
        manifest.append({'path': path.relative_to(context).as_posix(), 'bytes': len(body), 'sha256': hashlib.sha256(body).hexdigest()})
    archive = release / 'application.tar.gz'
    with tarfile.open(archive, 'w:gz') as output:
        for path in sorted(context.iterdir()):
            output.add(path, arcname=path.name)
    metadata = {'version': version, 'archive': str(PRIVATE / 'latest' / archive.name), 'archive_bytes': archive.stat().st_size,
                'files': len(manifest), 'manifest': manifest,
                'secrets_excluded_from_build': True, 'old_user_database_excluded': True,
                'image_source': 'astrologer-purple-stars.png'}
    (release / 'manifest.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
    return metadata


def verified_generated_directory(path: Path):
    allowed = {PRIVATE.resolve() / name for name in ('latest', 'previous')}
    if path.is_symlink() or path.resolve() not in allowed:
        raise RuntimeError('Unexpected deployment output path')
    try:
        manifest = json.loads((path / 'manifest.json').read_text(encoding='utf-8'))
    except (OSError, ValueError):
        raise RuntimeError('Existing output is not a recognized FATE release; leave it unchanged') from None
    if (manifest.get('secrets_excluded_from_build') is not True
            or manifest.get('old_user_database_excluded') is not True
            or not (path / 'application.tar.gz').is_file()):
        raise RuntimeError('Existing output is not a recognized FATE release; leave it unchanged')


def main():
    PRIVATE.mkdir(parents=True, exist_ok=True)
    staging, latest, previous = (PRIVATE / name for name in ('.building', 'latest', 'previous'))
    # A fixed staging directory prevents simultaneous runs from mixing releases.
    staging.mkdir()
    try:
        metadata = prepare(staging, datetime.now().strftime('%Y%m%d-%H%M%S'))
        for path in (latest, previous):
            if path.exists():
                verified_generated_directory(path)
        if previous.exists():
            shutil.rmtree(previous)
        if latest.exists():
            latest.rename(previous)
        try:
            staging.rename(latest)
        except OSError:
            if previous.exists() and not latest.exists():
                previous.rename(latest)
            raise
        (PRIVATE / 'latest.json').write_text(
            json.dumps({'version': metadata['version'], 'directory': str(latest)}, ensure_ascii=False),
            encoding='utf-8')
        print(json.dumps({key: metadata[key] for key in ('version', 'archive', 'archive_bytes', 'files',
                                                       'secrets_excluded_from_build', 'old_user_database_excluded')}, ensure_ascii=False))
    finally:
        # Only remove the staging directory exclusively created by this run.
        if staging.exists() and not staging.is_symlink() and staging.resolve() == PRIVATE.resolve() / '.building':
            shutil.rmtree(staging)


if __name__ == '__main__':
    main()
