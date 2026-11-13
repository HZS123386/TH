import gzip

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
    assert 'Accept-Encoding' in response.headers['vary']
    assert int(response.headers['content-length']) == len(gzip.compress(content, mtime=0))
    head = client.head('/thai-landing/main.wasm', headers={'Accept-Encoding': 'gzip'})
    assert head.content == b'' and head.headers['content-length'] == response.headers['content-length']
    cached = client.get('/thai-landing/main.wasm', headers={'Accept-Encoding': 'gzip', 'If-None-Match': response.headers['etag']})
    assert cached.status_code == 304 and cached.content == b''
    assert client.get('/thai-landing/', headers={'Accept-Encoding': 'gzip'}).content == b'<html>FATE</html>'


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
    assert 'content-encoding' not in response.headers
    assert client.get('/thai-landing/missing.wasm').status_code == 404
    assert client.get('/thai-landing/%2e%2e/private.wasm').status_code == 404
