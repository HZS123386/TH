"""Package the existing applications without local users or build-time secrets."""
from __future__ import annotations

import hashlib
import json
import shutil
import tarfile
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TH = ROOT.parent / 'TH'
PRIVATE = ROOT / 'output' / 'deploy'
SKIP = {'__pycache__', '.pytest_cache', '.ruff_cache', 'tests', 'node_modules', '.git'}


def copy_tree(source: Path, target: Path):
    shutil.copytree(source, target, symlinks=False,
                    ignore=lambda _directory, names: [name for name in names if name in SKIP or name.endswith(('.pyc', '.pyo'))])


def main():
    version = datetime.now().strftime('%Y%m%d-%H%M%S')
    release = PRIVATE / version
    context = release / 'context'
    context.mkdir(parents=True)
    for name in ('Dockerfile', 'compose.yaml', 'Caddyfile.ip'):
        shutil.copy2(ROOT / 'deploy' / name, context / name)
    copy_tree(TH / 'backend', context / 'TH' / 'backend')
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
    assert all(env.get(key) for key in ('QWEN_API_KEY', 'QWEN_BASE_URL', 'QWEN_MODEL'))
    config = {
        'APP_ENV': 'production',
        'DATABASE_PATH': 'data/sabai.db',
        'DEFAULT_PROVIDER': 'mock',
        'SESSION_HOURS': '168',
        'FORTUNE_PROVIDER': 'qwen',
        **{key: env[key] for key in ('QWEN_API_KEY', 'QWEN_BASE_URL', 'QWEN_MODEL')},
        'BAZI_REPORT_PROVIDER': 'qwen',
        'BAZI_REPORTS_PER_MINUTE': env.get('BAZI_REPORTS_PER_MINUTE', '0'),
        'BAZI_REPORTS_PER_DAY': env.get('BAZI_REPORTS_PER_DAY', '0'),
        'ROXY_ENABLED': 'false',
        'BAZI_PROVIDER': 'github',
        'THAI_LANDING_DIR': '/app/western-astrology-h5 4/site',
        'FATE_SUPPORT_EMAIL': env.get('FATE_SUPPORT_EMAIL', ''),
    }
    # This file is transferred separately and never enters the Docker build context.
    (release / 'runtime.env').write_text(''.join(f'{key}={value}\n' for key, value in config.items()), encoding='utf-8', newline='\n')
    (context / '.dockerignore').write_text('*.env\n.env*\ndata/\n*.pem\n*.key\n', encoding='utf-8')

    sensitive = [value for key, value in env.items() if value and any(part in key for part in ('API_KEY', 'SECRET', 'PASSWORD', 'TOKEN'))]
    manifest = []
    for path in sorted(context.rglob('*')):
        if not path.is_file():
            continue
        body = path.read_bytes()
        assert not any(secret.encode() in body for secret in sensitive), 'A local secret entered the build context'
        manifest.append({'path': path.relative_to(context).as_posix(), 'bytes': len(body), 'sha256': hashlib.sha256(body).hexdigest()})
    archive = release / 'application.tar.gz'
    with tarfile.open(archive, 'w:gz') as output:
        for path in sorted(context.iterdir()):
            output.add(path, arcname=path.name)
    metadata = {'version': version, 'archive': str(archive), 'archive_bytes': archive.stat().st_size,
                'files': len(manifest), 'manifest': manifest,
                'secrets_excluded_from_build': True, 'old_user_database_excluded': True,
                'image_source': 'astrologer-purple-stars.png'}
    (release / 'manifest.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
    (PRIVATE / 'latest.json').write_text(json.dumps({'version': version, 'directory': str(release)}, ensure_ascii=False), encoding='utf-8')
    print(json.dumps({key: metadata[key] for key in ('version', 'archive', 'archive_bytes', 'files', 'secrets_excluded_from_build', 'old_user_database_excluded')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
