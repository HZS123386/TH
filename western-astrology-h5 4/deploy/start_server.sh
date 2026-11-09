#!/usr/bin/env bash
set -euo pipefail
release=${1:?release version required}
expected=${2:?location index SHA256 required}
[[ "$release" =~ ^[0-9]{8}-[0-9]{6}$ && "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || exit 2
root=/opt/astro-life-report
target="$root/shared/data/birth-locations.sqlite3"
if [[ -f "$target" ]]; then
    actual=$(sha256sum "$target" | cut -d ' ' -f 1)
    [[ "${actual,,}" == "${expected,,}" ]] || { echo 'Existing location index differs' >&2; exit 4; }
else
    source="/home/ubuntu/astro-upload/$release/birth-locations.sqlite3"
    actual=$(sha256sum "$source" | cut -d ' ' -f 1)
    [[ "${actual,,}" == "${expected,,}" ]] || { echo 'Location index verification failed' >&2; exit 3; }
    install -o 10001 -g 10001 -m 644 "$source" "$target"
fi
cd "$root/releases/$release"
docker compose up -d --wait --wait-timeout 90
docker exec astro-life-report python -m pip check
docker exec astro-life-report node --version
docker exec -i astro-life-report python - <<'PY'
import json,urllib.request
from backend.app.config import Settings
s=Settings.from_env()
c=s.providers[s.fortune_provider]
assert c.enabled
for country in ('CN','TH'):
    url='http://127.0.0.1:8000/api/thai-locations?level=province&country='+country
    with urllib.request.urlopen(url) as response:
        value=json.load(response)
    assert value['items'], 'Empty province list'
    print(json.dumps({'country':country,'province_count':len(value['items'])}))
print(json.dumps({'app_env':s.app_env,'provider':s.fortune_provider,'model':c.model,'configured':c.enabled}))
PY
ln -sfn "$root/releases/$release" "$root/current"
printf 'INTERNAL_CHECKS_PASSED\n'
