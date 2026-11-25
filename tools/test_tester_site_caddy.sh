#!/usr/bin/env bash
# Checks deploy/testersite/service/install.sh against a copy of Dave's web server: Caddy (caddy:2-alpine) with basic_auth
# for two testers, the site folder mounted read-only, and a fake GitHub container. Needs Docker and root; uses port 18088.
#   sudo bash tools/test_tester_site_caddy.sh
# Runs install.sh on (a) a Caddyfile with nothing of ours, (b) one that already has the hand-added @home/templates lines,
# then (c) again on (b). Checks: Caddyfile validates with one @home, one templates, one reverse_proxy; no login = 401;
# a forged X-Dynasty-User is replaced by the real login; a bug sent through Caddy reaches GitHub signed by that login;
# the front page shows the login name.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
NET=tt-web
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
cleanup() { docker rm -f tt-game-web dynasty-reports tt-fake-github >/dev/null 2>&1 || true; docker network rm $NET >/dev/null 2>&1 || true; rm -rf "$T"; }
trap cleanup EXIT
cleanup; T="$(mktemp -d)"

HASH="$(docker run --rm caddy:2-alpine caddy hash-password --plaintext testpass)"
mkdir -p "$T/web/config" "$T/web/site" "$T/web/reports" "$T/gh"
echo '{"build": 9999, "zip": "/downloads/x.zip", "size_mb": 1}' > "$T/web/site/latest.json"
cat > "$T/gh/fake.py" <<'EOF'
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        d = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        with open("/out/log.jsonl", "a") as f: f.write(json.dumps({"path": self.path, "data": d}) + "\n")
        b = json.dumps({"number": 1, "html_url": "https://example/1"}).encode()
        self.send_response(201); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
ThreadingHTTPServer(("0.0.0.0", 9000), H).serve_forever()
EOF
caddyfile() {  # $1 = 1 to include the hand-added template lines
  { echo ":80 {"; echo "	basic_auth {"; echo "		alice $HASH"; echo "		bob $HASH"; echo "	}"; echo "	root * /srv"
    [ "$1" = 1 ] && { echo "	@home path / /index.html /download/ /download/index.html"; echo "	templates @home"; }
    echo "	file_server browse"; echo "}"; } > "$T/web/config/Caddyfile"
}
docker network create $NET >/dev/null
docker run -d --name tt-fake-github --network $NET -v "$T/gh:/out" python:3.12-alpine python -u /out/fake.py >/dev/null

for case in fresh hand-added; do
  docker rm -f tt-game-web dynasty-reports >/dev/null 2>&1 || true
  caddyfile "$([ $case = hand-added ] && echo 1 || echo 0)"
  docker run -d --name tt-game-web --network $NET -p 18088:80 -v "$T/web/config/Caddyfile:/etc/caddy/Caddyfile:ro" \
    -v "$T/web/site:/srv:ro" caddy:2-alpine >/dev/null
  sleep 1
  cp "$ROOT/deploy/testersite/service/install.sh" "$T/web/reports/"
  echo "GITHUB_API=http://tt-fake-github:9000" > "$T/web/reports/.env"
  echo github_pat_TEST > "$T/web/reports/github_token"
  for run in 1 2; do
    out="$(cd "$T/web/reports" && SOURCE="$ROOT/deploy/testersite" WEB_DIR="$T/web" CADDY=tt-game-web bash install.sh 2>&1)" \
      || { echo "$out"; echo "FAIL $case run $run: install.sh stopped"; exit 1; }
    check "$case run $run: install.sh DONE" 'grep -q "^DONE" <<<"$out"'
  done
  check "$case: second run changed nothing" 'grep -q "Already there" <<<"$out"'
  C="$T/web/config/Caddyfile"
  check "$case: one @home, one templates, one reverse_proxy" \
    '[ "$(grep -c "@home path" $C)$(grep -cE "^[[:space:]]*templates" $C)$(grep -c reverse_proxy $C)" = 111 ]'
  check "$case: Caddy accepts it" 'docker exec tt-game-web caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1'
  B=http://127.0.0.1:18088
  check "$case: no login = 401" '[ "$(curl -s -o /dev/null -w %{http_code} $B/api/me)" = 401 ]'
  check "$case: a forged name is replaced by the login" \
    'curl -s -u bob:testpass -H "X-Dynasty-User: alice" $B/api/me | grep -q "\"bob\""'
  check "$case: the front page shows the login name" 'curl -s -u bob:testpass $B/ | grep -q "<div class=\"who\">bob</div>"'
  curl -s -u alice:testpass -H "X-Dynasty-Form: 1" -F build="Build 9999" -F what="Through Caddy ($case)" $B/api/bug >/dev/null
  sleep 2
  check "$case: the bug reached GitHub signed by alice" "grep -q 'by \*\*alice\*\*' '$T/gh/log.jsonl' && grep -q 'Through Caddy ($case)' '$T/gh/log.jsonl'"
done
[ $fail = 0 ] && echo "all install checks passed" || { echo "some install checks failed"; exit 1; }
