#!/bin/sh
# Light checks that run on any OS (Linux CI included): no Swift needed.
set -eu
cd "$(dirname "$0")/.."
python3 -m py_compile mock/server.py
sh -n build.sh scripts/package.sh 2>/dev/null || bash -n build.sh
# the mock gateway must answer the endpoints the app uses
python3 mock/server.py 2>/dev/null & PID=$!
trap 'kill $PID 2>/dev/null' EXIT
sleep 1
for p in /v1/models "/v1/models?healthy_only=true" /key/info /spend/logs/v2 /health/liveliness; do
  python3 - "$p" <<'PY'
import sys, urllib.request
r = urllib.request.urlopen("http://127.0.0.1:4000" + sys.argv[1], timeout=5)
assert r.status == 200, sys.argv[1]
PY
done
# markdown links to local files must exist
for f in README.md docs/*.md; do
  d=$(dirname "$f")
  grep -o '](\([^)#h][^)#]*\)' "$f" | sed 's/](//' | while read -r l; do
    [ -e "$d/$l" ] || { echo "broken link in $f: $l"; exit 1; }
  done
done
echo "lint ok"
