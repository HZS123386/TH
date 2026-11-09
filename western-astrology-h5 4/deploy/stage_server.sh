#!/usr/bin/env bash
set -euo pipefail

release=${1:?release version required}
[[ "$release" =~ ^[0-9]{8}-[0-9]{6}$ ]] || exit 2
upload="/home/ubuntu/astro-upload/$release"
root=/opt/astro-life-report
destination="$root/releases/$release"

install -d -m 750 "$root" "$root/releases" "$root/shared" "$destination"
install -d -o 10001 -g 10001 -m 750 "$root/shared/data"
tar -xzf "$upload/application.tar.gz" -C "$destination"
python3 - "$upload/manifest.json" "$destination" <<'PY'
import hashlib,json,sys
from pathlib import Path
manifest=json.load(open(sys.argv[1]))
root=Path(sys.argv[2]).resolve()
for item in manifest['manifest']:
    target=(root/item['path']).resolve()
    if root not in target.parents:
        raise RuntimeError('Invalid manifest path')
    if hashlib.sha256(target.read_bytes()).hexdigest()!=item['sha256']:
        raise RuntimeError('Release file verification failed')
print('RELEASE_FILES_VERIFIED',len(manifest['manifest']))
PY

if [[ -f "$root/shared/runtime.env" ]]; then
    cmp --silent "$upload/runtime.env" "$root/shared/runtime.env" || {
        echo 'Existing runtime settings differ; leave them unchanged.' >&2
        exit 3
    }
else
    install -o root -g root -m 600 "$upload/runtime.env" "$root/shared/runtime.env"
fi
install -m 644 "$upload/manifest.json" "$destination/manifest.json"
printf 'ASTRO_RELEASE=%s\n' "$release" > "$destination/.env"
chmod 600 "$destination/.env"
cd "$destination"
docker compose config --quiet
docker compose build app
printf 'IMAGE_BUILT %s\n' "$release"
