#!/usr/bin/env bash
# Installs or updates the tester site's report service and pages on Dave's game server (deploy/testersite/INSTALL.md).
# Run it from /data/game-web/reports:   sudo bash install.sh
# It is safe to run again (an update): it keeps the token, the reports and every other setting.
#
# What it does, in order:
#   1. fetches reports.py, compose.yaml and the site pages from the game repo on GitHub (branch $BRANCH, default dev)
#   2. asks once for the GitHub token and keeps it in ./github_token (only root can read it; never in the site folder)
#   3. finds Caddy's Docker network and the tester login names (from the Caddyfile's basic_auth lines) and writes ./.env
#   4. starts the service (container dynasty-reports, no port of its own on the server)
#   5. copies the pages into the site folder (bug.html, idea.html, index.html, css/, js/), keeping a copy of the old index.html
#   6. adds to the Caddyfile (once, with a backup) the /api/ reverse_proxy block and, if missing, `templates` for the pages
#      that show the login name (deploy/testplayers/SERVER.md step 3), checks it and reloads Caddy;
#      if Caddy does not accept it, the old Caddyfile is put back and nothing else changes
#   7. checks that Caddy can reach the service
set -euo pipefail

BRANCH="${BRANCH:-dev}"
RAW="https://raw.githubusercontent.com/DSul3791/DynastyALWL/${BRANCH}/deploy/testersite"
SOURCE="${SOURCE:-}"                     # a local deploy/testersite folder instead of GitHub (used by the tests)
WEB_DIR="${WEB_DIR:-/data/game-web}"
SITE="$WEB_DIR/site"
CADDYFILE="$WEB_DIR/config/Caddyfile"
CADDY="${CADDY:-game-web}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

say() { printf '\n== %s\n' "$*"; }
die() { printf '\nSTOPPED: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "run it with sudo:  sudo bash install.sh"
command -v docker >/dev/null || die "docker is not installed here"
docker inspect "$CADDY" >/dev/null 2>&1 || die "there is no container called $CADDY (the web server)"
[ -f "$CADDYFILE" ] || die "no Caddyfile at $CADDYFILE"
[ -d "$SITE" ] || die "no site folder at $SITE"
case "$HERE" in "$SITE"*) die "this folder is inside the web site; use $WEB_DIR/reports" ;; esac

say "1. Getting the files (branch $BRANCH)"
fetch() {  # fetch <path inside deploy/testersite> <where to put it>
  mkdir -p "$(dirname "$2")"
  if [ -n "$SOURCE" ]; then cp "$SOURCE/$1" "$2.new"; else curl -fsSL "$RAW/$1" -o "$2.new"; fi
  mv "$2.new" "$2"
}
fetch service/reports.py reports.py
fetch service/compose.yaml compose.yaml
mkdir -p pages
for f in index.html bug.html idea.html css/dynasty.css js/tester.js; do fetch "site/$f" "pages/$f"; done
python3 -c 'import ast,sys; ast.parse(open("reports.py").read())' 2>/dev/null || grep -q "def main" reports.py \
  || die "reports.py did not download properly"
echo "ok"

say "2. GitHub token"
if [ -s github_token ]; then
  echo "Keeping the token already in $HERE/github_token"
else
  echo "Paste the GitHub token (it starts with github_pat_), then press Enter. Nothing shows while you paste."
  read -rs TOKEN </dev/tty
  echo
  case "$TOKEN" in github_pat_*|ghp_*) ;; *) die "that does not look like a GitHub token; run this again" ;; esac
  umask 077
  printf '%s\n' "$TOKEN" > github_token
  unset TOKEN
fi
chmod 600 github_token
echo "ok"

say "3. Settings"
NET="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$CADDY" | awk '{print $1}')"
[ -n "$NET" ] || die "could not find the Docker network of $CADDY"
[ "$NET" != host ] || die "$CADDY uses the host network; ask for the other set-up in INSTALL.md"
TESTERS="$(grep -E '^[[:space:]]*[^#[:space:]]+[[:space:]]+\$2[aby]\$' "$CADDYFILE" | awk '{print $1}' | sort -u | paste -sd, -)"
touch .env
grep -vE '^(WEB_NETWORK|TESTERS)=' .env > .env.new || true
printf 'WEB_NETWORK=%s\nTESTERS=%s\n' "$NET" "$TESTERS" >> .env.new
mv .env.new .env
echo "Caddy's network: $NET"
echo "Testers on the high-score table: ${TESTERS:-none found (they appear once they send something)}"

say "4. Starting the report service"
mkdir -p data
docker compose up -d --force-recreate
echo "ok"

say "5. Copying the pages into $SITE"
OWNER="$(stat -c %U:%G "$SITE")"
if [ -f "$SITE/index.html" ] && ! grep -q 'id="scores"' "$SITE/index.html"; then
  cp -p "$SITE/index.html" "$SITE/index.before-reports.html"
  echo "The old front page is kept as index.before-reports.html"
fi
cp -r pages/. "$SITE/"
chown -R "$OWNER" "$SITE/index.html" "$SITE/bug.html" "$SITE/idea.html" "$SITE/css" "$SITE/js"
echo "ok"

say "6. Caddy: /api/ to the report service, and the login name on the pages"
NEED_API=1; NEED_TPL=1
grep -q 'dynasty-reports:8080' "$CADDYFILE" && NEED_API=0
grep -qE '^[[:space:]]*templates' "$CADDYFILE" && NEED_TPL=0
if [ "$NEED_API$NEED_TPL" = "00" ]; then
  echo "Already there; nothing to change."
else
  grep -qE '^[[:space:]]*file_server' "$CADDYFILE" || die "no file_server line in the Caddyfile; see INSTALL.md, 'By hand'"
  cp -p "$CADDYFILE" "$CADDYFILE.before-reports"
  awk -v api="$NEED_API" -v tpl="$NEED_TPL" '
    !done && /^[[:space:]]*file_server/ {
      match($0, /^[[:space:]]*/); pad = substr($0, 1, RLENGTH)
      if (tpl == 1) {
        print pad "# Tester site (deploy/testersite/INSTALL.md): Caddy writes the login name into these pages."
        print pad "@home path / /index.html /download/ /download/index.html"
        print pad "templates @home"
      }
      if (api == 1) {
        print pad "# Tester site report service: the login name goes with every /api/ request."
        print pad "reverse_proxy /api/* dynasty-reports:8080 {"
        print pad "\theader_up X-Dynasty-User {http.auth.user.id}"
        print pad "\theader_up -Authorization"
        print pad "}"
      }
      done = 1
    }
    { print }' "$CADDYFILE.before-reports" > "$HERE/Caddyfile.new"
  # Write into the same file (not a new one), so the container, which mounts this exact file, sees the change.
  cat "$HERE/Caddyfile.new" > "$CADDYFILE"
  rm -f "$HERE/Caddyfile.new"
  if docker exec "$CADDY" caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1 \
     && docker exec "$CADDY" caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
    echo "Added, checked and loaded. The old file is $CADDYFILE.before-reports"
  else
    cat "$CADDYFILE.before-reports" > "$CADDYFILE"
    die "Caddy did not accept the change, so the old Caddyfile is back as it was. The pages are copied; /api/ is not connected."
  fi
fi

say "7. Checking"
ok=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if docker exec "$CADDY" wget -qO- http://dynasty-reports:8080/api/health 2>/dev/null | grep -q '"ok"'; then ok=1; break; fi
  sleep 1
done
[ -n "$ok" ] || die "Caddy cannot reach the report service. Run: sudo docker logs --tail 50 dynasty-reports"
echo "Caddy reaches the report service."
echo
echo "DONE. Open https://hannibalshouse.duckdns.org/ and log in: the high-score table shows under the three boxes."
echo "Send a test bug from the Submit a bug page, then check https://github.com/DSul3791/DynastyALWL-QA/issues"
