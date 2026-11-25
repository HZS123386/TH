import gzip
from pathlib import Path
from runpy import run_path

import pytest
from starlette.applications import Starlette
from starlette.routing import Mount
from starlette.testclient import TestClient

from backend.app.static_assets import LandingStaticFiles

# A standard Brotli stream for b'web-assembly-payload' * 200. Tests inspect the
# raw response, so the production/test environment needs no Python Brotli package.
BROTLI_PAYLOAD = bytes.fromhex('1b9f0ff81da98dfe367a590677d761626479b285edad4cf9ad4688c454460700e226')

@pytest.fixture
def assets(tmp_path):
    content = b'web-assembly-payload' * 200
    (tmp_path / 'main.wasm').write_bytes(content)
    (tmp_path / 'main.wasm.gz').write_bytes(gzip.compress(content, mtime=0))
    (tmp_path / 'main.wasm.br').write_bytes(BROTLI_PAYLOAD)
    (tmp_path / 'gzip-only.wasm').write_bytes(content)
    (tmp_path / 'gzip-only.wasm.gz').write_bytes(gzip.compress(content, mtime=0))
    (tmp_path / 'index.html').write_text('<html>FATE</html>')
    (tmp_path / 'index.html.gz').write_bytes(gzip.compress(b'<html>FATE</html>', mtime=0))
    app = Starlette(routes=[Mount('/thai-landing', LandingStaticFiles(directory=tmp_path, html=True))])
    with TestClient(app) as client:
        yield client, content


def test_precompressed_get_head_and_conditional_cache_preserve_content_and_mime(assets):
    client, content = assets
    response = client.get('/thai-landing/main.wasm', headers={'Accept-Encoding': 'gzip'})
    assert response.status_code == 200 and response.content == content
    assert response.headers['content-type'] == 'application/wasm'
    assert response.headers['content-encoding'] == 'gzip'
    assert response.headers['cache-control'] == 'no-cache'
    assert 'Accept-Encoding' in response.headers['vary']
    assert int(response.headers['content-length']) == len(gzip.compress(content, mtime=0))
    head = client.head('/thai-landing/main.wasm', headers={'Accept-Encoding': 'gzip'})
    assert head.content == b'' and head.headers['content-length'] == response.headers['content-length']
    assert head.headers['cache-control'] == 'no-cache'
    cached = client.get('/thai-landing/main.wasm', headers={'Accept-Encoding': 'gzip', 'If-None-Match': response.headers['etag']})
    assert cached.status_code == 304 and cached.content == b''
    assert cached.headers['cache-control'] == 'no-cache'
    index = client.get('/thai-landing/', headers={'Accept-Encoding': 'gzip'})
    assert index.content == b'<html>FATE</html>'
    assert index.headers['cache-control'] == 'no-cache'


@pytest.mark.parametrize('encoding', ['identity', 'gzip;q=0', '*;q=1, gzip;q=0, br;q=0', 'gzip;q=invalid'])
def test_rejected_gzip_returns_original_representation(assets, encoding):
    client, content = assets
    response = client.get('/thai-landing/main.wasm', headers={'Accept-Encoding': encoding})
    assert response.content == content and 'content-encoding' not in response.headers
    assert int(response.headers['content-length']) == len(content)


@pytest.mark.parametrize(('accept', 'selected'), [
    ('gzip, br', 'br'),
    ('gzip;q=1, br;q=0.5', 'gzip'),
    ('identity;q=1, br;q=0.5', None),
    ('*;q=1, gzip;q=0', 'br'),
    ('br;q=0, gzip', 'gzip'),
    ('br;q=0, gzip;q=0', None),
])
def test_brotli_quality_selection_and_explicit_rejection(assets, accept, selected):
    client, content = assets
    expected = {'br': BROTLI_PAYLOAD, 'gzip': gzip.compress(content, mtime=0), None: content}[selected]
    with client.stream('GET', '/thai-landing/main.wasm', headers={'Accept-Encoding': accept}) as response:
        assert response.status_code == 200
        assert response.headers['cache-control'] == 'no-cache'
        assert response.headers.get('content-encoding') == selected
        assert response.headers['content-type'] == 'application/wasm'
        assert int(response.headers['content-length']) == len(expected)
        assert b''.join(response.iter_raw()) == expected


def test_brotli_head_conditional_cache_fallback_and_unacceptable_encodings(assets):
    client, _ = assets
    head = client.head('/thai-landing/main.wasm', headers={'Accept-Encoding': 'br'})
    assert head.status_code == 200 and head.content == b''
    assert head.headers['content-encoding'] == 'br'
    assert int(head.headers['content-length']) == len(BROTLI_PAYLOAD)
    cached = client.get('/thai-landing/main.wasm', headers={'Accept-Encoding': 'br', 'If-None-Match': head.headers['etag']})
    assert cached.status_code == 304 and cached.content == b''
    assert cached.headers['content-encoding'] == 'br' and 'Accept-Encoding' in cached.headers['vary']
    fallback = client.get('/thai-landing/gzip-only.wasm', headers={'Accept-Encoding': 'br, gzip'})
    assert fallback.status_code == 200 and fallback.headers['content-encoding'] == 'gzip'
    for headers in ({'Accept-Encoding': '*;q=0'}, {'Accept-Encoding': 'br, identity;q=0', 'Range': 'bytes=0-7'}):
        rejected = client.get('/thai-landing/main.wasm', headers=headers)
        assert rejected.status_code == 406
        assert 'Accept-Encoding' in rejected.headers['vary']


def test_ranges_missing_files_and_path_boundaries_retain_static_file_behavior(assets):
    client, content = assets
    response = client.get('/thai-landing/main.wasm', headers={'Accept-Encoding': 'gzip', 'Range': 'bytes=0-7'})
    assert response.status_code == 206 and response.content == content[:8]
    assert response.headers['cache-control'] == 'no-cache'
    assert 'content-encoding' not in response.headers
    assert client.get('/thai-landing/missing.wasm').status_code == 404
    assert client.get('/thai-landing/%2e%2e/private.wasm').status_code == 404


@pytest.mark.parametrize('encoding', ['identity', 'gzip'])
def test_app_assets_revalidate_to_new_build_instead_of_reusing_old_content(assets, tmp_path, encoding):
    client, _ = assets
    headers = {'Accept-Encoding': encoding}
    original = client.get('/thai-landing/main.wasm', headers=headers)
    updated = b'new-app-build' * 500
    (tmp_path / 'main.wasm').write_bytes(updated)
    (tmp_path / 'main.wasm.gz').write_bytes(gzip.compress(updated, mtime=0))

    response = client.get('/thai-landing/main.wasm', headers={**headers, 'If-None-Match': original.headers['etag']})
    assert response.status_code == 200 and response.content == updated
    assert response.headers['etag'] != original.headers['etag']
    assert response.headers['cache-control'] == 'no-cache'
    cached = client.get('/thai-landing/main.wasm', headers={**headers, 'If-None-Match': response.headers['etag']})
    assert cached.status_code == 304
    assert cached.headers['cache-control'] == 'no-cache'


@pytest.mark.parametrize('encoding', ['identity', 'gzip'])
def test_revisioned_engine_retains_long_cache_for_unchanged_runtime(assets, tmp_path, encoding):
    client, _ = assets
    engine = tmp_path / 'engine' / ('a' * 40)
    engine.mkdir(parents=True)
    content = b'unchanged-engine'
    (engine / 'skwasm.wasm').write_bytes(content)
    (engine / 'skwasm.wasm.gz').write_bytes(gzip.compress(content, mtime=0))
    url = f'/thai-landing/engine/{engine.name}/skwasm.wasm'
    headers = {'Accept-Encoding': encoding}
    response = client.get(url, headers=headers)
    assert response.status_code == 200 and response.content == content
    assert response.headers['cache-control'] == 'public, max-age=31536000, immutable'
    cached = client.get(url, headers={**headers, 'If-None-Match': response.headers['etag']})
    assert cached.status_code == 304
    assert cached.headers['cache-control'] == response.headers['cache-control']


def test_release_redirects_only_offloaded_startup_wasm(tmp_path):
    root = Path(__file__).resolve().parents[3]
    packaging = root / 'western-astrology-h5 4' / 'deploy' / 'prepare_release.py'
    offload_wasm = run_path(str(packaging))['offload_wasm']
    site = tmp_path / 'site'
    revision = 'a' * 40
    engine = site / 'engine' / revision
    engine.mkdir(parents=True)
    main = site / 'main.dart.wasm'
    main.write_bytes(b'web-assembly-payload' * 200)
    main.with_suffix('.wasm.br').write_bytes(BROTLI_PAYLOAD)
    main.with_suffix('.wasm.gz').write_bytes(gzip.compress(main.read_bytes(), mtime=0))
    renderer = engine / 'skwasm.wasm'
    renderer.write_bytes(b'renderer')
    (engine / 'skwasm_heavy.wasm').write_bytes(b'heavy renderer')
    (site / 'main.dart_module1.wasm').write_bytes(b'deferred module')

    release = tmp_path / 'release'
    assert offload_wasm(site, release, '') == [] and main.is_file()
    storage = 'https://assets.example.invalid/fate'
    uploads = offload_wasm(site, release, storage)
    assert len(uploads) == 3
    assert not main.exists() and not renderer.exists()
    assert not main.with_suffix('.wasm.br').exists() and not main.with_suffix('.wasm.gz').exists()
    compressed = next(item for item in uploads if item['content_encoding'] == 'br')
    assert compressed['content_type'] == 'application/wasm'
    assert (release / compressed['path']).read_bytes() == BROTLI_PAYLOAD

    app = Starlette(routes=[Mount('/thai-landing', LandingStaticFiles(directory=site, html=True))])
    with TestClient(app, follow_redirects=False) as client:
        prefix = '/thai-landing/'
        result = client.get(prefix + 'main.dart.wasm', headers={'Accept-Encoding': 'br'})
        assert result.status_code == 307 and result.content == b''
        assert result.headers['location'] == f"{storage}/{compressed['object_key']}"
        assert result.headers['cache-control'] == 'no-store'
        assert result.headers['vary'] == 'Accept-Encoding'
        identity = next(item for item in uploads if item['object_key'].endswith('/main.dart.wasm')
                        and item['content_encoding'] is None)
        raw = client.head(prefix + 'main.dart.wasm', headers={'Accept-Encoding': 'identity'})
        assert raw.headers['location'] == f"{storage}/{identity['object_key']}"
        engine_response = client.get(prefix + f'engine/{revision}/skwasm.wasm')
        assert engine_response.status_code == 307 and engine_response.headers['location'].endswith('/skwasm.wasm')
        assert client.get(prefix + f'engine/{revision}/skwasm_heavy.wasm').content == b'heavy renderer'
        assert client.get(prefix + 'main.dart_module1.wasm').content == b'deferred module'
