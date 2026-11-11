"""Improve release gzip files without changing their decoded contents."""
from pathlib import Path
import gzip
import sys

from zopfli.gzip import compress


root = Path(sys.argv[1]).resolve()
if not (root / 'index.html').is_file() or not (root / 'main.dart.js').is_file():
    raise SystemExit('Expected a completed Flutter web build directory')
saved = 0
count = 0
for source in sorted(root.rglob('*')):
    if not source.is_file() or source.suffix not in {'.wasm', '.js', '.mjs'} or source.stat().st_size < 1024:
        continue
    target = source.with_name(source.name + '.gz')
    original = source.read_bytes()
    encoded = compress(original, numiterations=5)
    if gzip.decompress(encoded) != original:
        raise RuntimeError(f'Compressed data verification failed: {source.name}')
    previous = target.read_bytes()
    if len(encoded) < len(previous):
        target.write_bytes(encoded)
        saved += len(previous) - len(encoded)
    count += 1
print(f'Optimized {count} release gzip files; saved {saved} additional bytes.', flush=True)
