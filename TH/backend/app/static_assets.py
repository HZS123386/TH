from pathlib import PurePosixPath
import mimetypes

from starlette.exceptions import HTTPException
from starlette.responses import Response
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

    async def get_response(self, path, scope):
        response = await super().get_response(path, scope)
        asset = 'index.html' if path in ('', '.') else path
        suffix = PurePosixPath(asset).suffix.lower()
        if response.status_code not in (200, 206, 304):
            return response
        headers = {key.lower(): value for key, value in scope['headers']}
        encodings = accepted_encodings(headers.get(b'accept-encoding', b'').decode('latin1'))
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
                compressed.headers.add_vary_header('Accept-Encoding')
                return compressed
        return Response(status_code=406, headers={'Vary': 'Accept-Encoding'})
