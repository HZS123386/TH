import importlib.util
import json
import tarfile
from pathlib import Path

import pytest


@pytest.fixture
def release(tmp_path):
    script = Path(__file__).resolve().parents[3] / 'western-astrology-h5 4/deploy/prepare_release.py'
    spec = importlib.util.spec_from_file_location('fate_prepare_release', script)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = tmp_path / 'h5'
    module.TH = tmp_path / 'TH'
    module.PRIVATE = tmp_path / 'output/deploy'
    for name in ('backend', 'scripts', 'src/content', 'src/locales', 'src/data', 'node_modules/thai-astrology'):
        folder = module.TH / name
        folder.mkdir(parents=True)
        (folder / 'fixture.txt').write_text('source fixture', encoding='utf-8')
    (module.TH / 'package.json').write_text('{}', encoding='utf-8')
    (module.ROOT / 'deploy').mkdir(parents=True)
    for name in ('Dockerfile', 'compose.yaml', 'Caddyfile.ip', 'Caddyfile.domain'):
        (module.ROOT / 'deploy' / name).write_text('deployment fixture', encoding='utf-8')
    (module.ROOT / 'site').mkdir()
    (module.ROOT / 'site/index.html').write_text('compiled landing', encoding='utf-8')
    (module.TH / '.env').write_text(
        'QWEN_API_KEY=test-qwen-secret\nQWEN_BASE_URL=https://example.test/v1\nQWEN_MODEL=test-model\n'
        'ROXY_ENABLED=true\nROXY_API_KEY=test-roxy-secret\nLIFE_ASTROLOGY_PROVIDER=roxy\n', encoding='utf-8')
    return module


def test_fixed_output_rotates_and_removes_stale_build_files(release):
    release.main()
    latest, previous = release.PRIVATE / 'latest', release.PRIVATE / 'previous'
    assert latest.is_dir() and not previous.exists()
    (release.TH / 'backend/fixture.txt').unlink()
    (release.TH / 'backend/new.txt').write_text('new backend', encoding='utf-8')
    release.main()
    assert not (latest / 'context/TH/backend/fixture.txt').exists()
    assert (latest / 'context/TH/backend/new.txt').exists()
    assert (previous / 'context/TH/backend/fixture.txt').exists()
    release.main()
    assert {p.name for p in release.PRIVATE.iterdir()} == {'latest', 'previous', 'latest.json'}
    assert json.loads((release.PRIVATE / 'latest.json').read_text())['directory'] == str(latest)


def test_runtime_preserves_roxy_and_secrets_stay_outside_archive(release):
    (release.TH / 'data').mkdir()
    (release.TH / 'data/sabai.db').write_bytes(b'private user data')
    release.main()
    latest = release.PRIVATE / 'latest'
    runtime = (latest / 'runtime.env').read_text()
    assert 'APP_ENV=production' in runtime and 'ROXY_ENABLED=true' in runtime
    assert 'LIFE_ASTROLOGY_PROVIDER=roxy' in runtime and 'ROXY_API_KEY=test-roxy-secret' in runtime
    with tarfile.open(latest / 'application.tar.gz') as archive:
        names = archive.getnames()
        assert not any('.env' in name or 'sabai.db' in name for name in names)
        for member in archive.getmembers():
            if member.isfile():
                body = archive.extractfile(member).read()
                assert b'test-roxy-secret' not in body and b'test-qwen-secret' not in body


def test_runtime_carries_live_payment_and_configured_report_writers(release):
    with (release.TH / '.env').open('a', encoding='utf-8') as env:
        env.write('FORTUNE_PROVIDER=openai\nFORTUNE_FALLBACK_PROVIDER=qwen\n'
                  'OPENAI_API_KEY=test-openai-secret\nOPENAI_BASE_URL=https://example.test/v1\n'
                  'OPENAI_MODEL=test-writer\nOPENAI_REASONING_EFFORT=low\n'
                  'WESTERN_REVIEW_ENABLED=true\nWESTERN_REVIEW_PROVIDER=kimi\n'
                  'KIMI_API_KEY=test-kimi-secret\nKIMI_MODEL=test-review\n'
                  'SUNLANDS_ORDER_ONLY=true\nSUNLANDS_BASE_URL=https://api-prod.sunlands.com\n'
                  'SUNLANDS_APP_SECRET=test-payment-secret\nSUNLANDS_PROVINCE_ID=4\n')
    release.main()
    latest = release.PRIVATE / 'latest'
    runtime = (latest / 'runtime.env').read_text()
    for setting in ('FORTUNE_PROVIDER=openai', 'FORTUNE_FALLBACK_PROVIDER=qwen',
                    'OPENAI_API_KEY=test-openai-secret', 'OPENAI_REASONING_EFFORT=low',
                    'WESTERN_REVIEW_ENABLED=true', 'KIMI_API_KEY=test-kimi-secret',
                    'SUNLANDS_ORDER_ONLY=true', 'SUNLANDS_APP_SECRET=test-payment-secret'):
        assert setting in runtime
    with tarfile.open(latest / 'application.tar.gz') as archive:
        for member in archive.getmembers():
            if member.isfile():
                body = archive.extractfile(member).read()
                assert all(secret not in body for secret in (
                    b'test-openai-secret', b'test-kimi-secret', b'test-payment-secret'))


def test_runtime_rejects_test_payment_gateway_in_production(release):
    with (release.TH / '.env').open('a', encoding='utf-8') as env:
        env.write('SUNLANDS_ORDER_ONLY=true\nSUNLANDS_BASE_URL=https://api-test.sunlands.com\n'
                  'SUNLANDS_APP_SECRET=test-payment-secret\nSUNLANDS_PROVINCE_ID=4\n')
    with pytest.raises(RuntimeError, match='Production Sunlands'):
        release.main()
    assert not (release.PRIVATE / 'latest').exists()


def test_unrecognized_existing_output_is_preserved(release):
    release.main()
    previous = release.PRIVATE / 'previous'
    previous.mkdir()
    sentinel = previous / 'keep.txt'
    sentinel.write_text('not a generated release', encoding='utf-8')
    with pytest.raises(RuntimeError, match='not a recognized'):
        release.main()
    assert sentinel.read_text() == 'not a generated release'
    assert (release.PRIVATE / 'latest/application.tar.gz').exists()
    assert not (release.PRIVATE / '.building').exists()


def test_secret_in_compiled_assets_rejects_package(release):
    (release.ROOT / 'site/index.html').write_text('test-roxy-secret', encoding='utf-8')
    with pytest.raises(RuntimeError, match='local secret'):
        release.main()
    assert not (release.PRIVATE / 'latest').exists()
    assert not (release.PRIVATE / '.building').exists()


def test_failed_publication_restores_the_existing_release(release, monkeypatch):
    release.main()
    latest = release.PRIVATE / 'latest'
    original = (latest / 'manifest.json').read_bytes()
    rename = Path.rename

    def fail_publish(path, target):
        if path == release.PRIVATE / '.building':
            raise OSError('simulated publication failure')
        return rename(path, target)

    monkeypatch.setattr(Path, 'rename', fail_publish)
    with pytest.raises(OSError, match='simulated publication failure'):
        release.main()
    assert (latest / 'manifest.json').read_bytes() == original
    assert not (release.PRIVATE / 'previous').exists()
    assert not (release.PRIVATE / '.building').exists()
