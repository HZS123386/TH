from pathlib import Path, PurePosixPath
import json
import mimetypes
import re
from urllib.parse import urlsplit

from starlette.exceptions import HTTPException
from starlette.responses import RedirectResponse, Response
from starlette.staticfiles import StaticFiles


def accepted_encodings(value: str) -> list[str]:
    qualities: dict[str, float] = {}
    for item in value.lower().split(','):
        encoding, *parameters = item.strip().split(';')
        quality = next((p.strip()[2:] for p in parameters if p.strip().startswith('q=')), '1')
        try:
            weight = float(quality)
        except ValueError:
            weight = 0
        qualities[encoding.strip()] = weight if 0 <= weight <= 1 else 0
    # Prefer Brotli on a tie, while respecting explicit exclusions over '*'.
    preferred = sorted(
        (name for name in ('br', 'gzip') if qualities.get(name, qualities.get('*', 0)) > 0),
        key=lambda name: qualities.get(name, qualities.get('*', 0)),
        reverse=True,
    )
    identity = qualities.get('identity', 0 if qualities.get('*') == 0 else 1)
    if identity > 0:
        if 'identity' in qualities:
            preferred.append('identity')
            preferred.sort(key=lambda name: qualities.get(name, qualities.get('*', 0)), reverse=True)
        else:
            preferred.append('identity')
    return preferred


class LandingStaticFiles(StaticFiles):
    """Negotiate build-time Brotli/gzip files through the existing landing mount."""

    def __init__(self, *, directory=None, **options):
        super().__init__(directory=directory, **options)
        self.wasm_redirects = {}
        manifest = Path(directory) / 'wasm-redirects.json' if directory is not None else None
        if manifest and manifest.is_file():
            redirects = json.loads(manifest.read_text(encoding='utf-8'))
            if (not isinstance(redirects, dict) or len(redirects) != 2 or 'main.dart.wasm' not in redirects
                    or any(path != 'main.dart.wasm' and not re.fullmatch(r'engine/[a-f0-9]{40}/skwasm\.wasm', path)
                           for path in redirects)):
                raise ValueError('Invalid H5 Wasm redirect paths')
            for variants in redirects.values():
                if not isinstance(variants, dict) or 'identity' not in variants or variants.keys() - {'identity', 'br'}:
                    raise ValueError('Invalid H5 Wasm redirect variants')
                for url in variants.values():
                    if not isinstance(url, str) or any(char.isspace() for char in url) or '\\' in url:
                        raise ValueError('Invalid H5 Wasm redirect URL')
                    address = urlsplit(url)
                    if (address.scheme != 'https' or not address.hostname or address.username is not None
                            or address.query or address.fragment):
                        raise ValueError('H5 Wasm redirects require public HTTPS URLs')
            self.wasm_redirects = redirects

    async def get_response(self, path, scope):
        asset = 'index.html' if path in ('', '.') else path.replace('\\', '/')
        headers = {key.lower(): value for key, value in scope['headers']}
        encodings = accepted_encodings(headers.get(b'accept-encoding', b'').decode('latin1'))
        variants = self.wasm_redirects.get(asset)
        if variants and scope['method'] in {'GET', 'HEAD'}:
            for encoding in encodings:
                if encoding in variants and (b'range' not in headers or encoding == 'identity'):
                    return RedirectResponse(variants[encoding], headers={
                        'Cache-Control': 'no-store', 'Vary': 'Accept-Encoding',
                    })
            return Response(status_code=406, headers={'Vary': 'Accept-Encoding'})
        response = await super().get_response(path, scope)
        suffix = PurePosixPath(asset).suffix.lower()
        if response.status_code not in (200, 206, 304):
            return response
        # Stable app URLs must revalidate; only revisioned engine files are immutable.
        cache_control = ('public, max-age=31536000, immutable'
                         if re.match(r'^engine/[a-f0-9]{40}/', asset) else 'no-cache')
        response.headers['Cache-Control'] = cache_control
        if b'range' in headers or suffix not in {'.html', '.js', '.mjs', '.css', '.json', '.svg', '.wasm', '.ttf', '.otf'}:
            encodings = [name for name in encodings if name == 'identity']
        for encoding in encodings:
            if encoding == 'identity':
                response.headers.add_vary_header('Accept-Encoding')
                return response
            extension = '.br' if encoding == 'br' else '.gz'
            try:
                compressed = await super().get_response(asset + extension, scope)
            except HTTPException as error:
                if error.status_code != 404:
                    raise
            else:
                if compressed.status_code not in (200, 304):
                    response.headers.add_vary_header('Accept-Encoding')
                    return response
                compressed.headers['Content-Encoding'] = encoding
                compressed.headers['Content-Type'] = response.headers.get('content-type') or mimetypes.guess_type(asset)[0] or 'application/octet-stream'
                compressed.headers['Cache-Control'] = cache_control
                compressed.headers.add_vary_header('Accept-Encoding')
                return compressed
        return Response(status_code=406, headers={'Vary': 'Accept-Encoding'})
