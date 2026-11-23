# The test players' page on Dave's web server

Dave set up the web server on 22 Nov 2026. It is Caddy in Docker on the Ubuntu game server **dell-gameserver-01**, the same computer as David4.
- Address: https://hannibalshouse.duckdns.org/
- Login: HTTPS and a login for the four test players are already set up there, for the whole site.
- Site root: `/data/game-web/site/` on the host. It belongs to dave, and the container reads it as `/srv`.

On 23 Nov Dave asked that people who log in land straight on the test players' page, so the page is the site's `index.html`. Nothing here touches the server's Caddyfile, its compose file, the login or the certificates.

**Status: not yet run.** These steps have not been tried on the server.

## 1. Make the site folder (Dave's PC, after `tools\make_release.ps1`)

```
powershell -ExecutionPolicy Bypass -File tools\make_testplayers_site.ps1 -Out ..\dynasty_export\build-<N>
```

It writes `..\dynasty_export\build-<N>\site\`, laid out exactly like `/data/game-web/site/`:

| On the server | Address |
|---|---|
| `index.html` | https://hannibalshouse.duckdns.org/ (the page: download, install, join, report) |
| `images/hero.jpg`, `fonts/` | the page's picture and the menu fonts, with their licence |
| `downloads/Dynasty-build-<N>.zip` | https://hannibalshouse.duckdns.org/downloads/Dynasty-build-N.zip |
| `files.sha256` | the SHA-256 of every other file, for the check in step 3 |

All the page's links start with `/`. File names have no spaces.

## 2. Copy it up (Dave, PowerShell on his PC)

Replace `<N>` with the build number. Replace `HOST` with `dell-gameserver-01`, or with its LAN address if that name does not resolve from the PC. Type the password when asked, or use your SSH key. No password goes in any file.

```
cd E:\Software\godotDev\dynasty_export\build-<N>\site
scp -r index.html files.sha256 images fonts downloads dave@HOST:/data/game-web/site/
```

- This replaces `index.html` (the placeholder page) and adds the build's zip to `downloads/`. Caddy picks up changes without a restart.
- **Older zips stay** in `downloads/` until you remove them. The four testers can see them, because `/downloads/` shows a file list. To list them, then remove one:

```
ssh dave@HOST "ls -l /data/game-web/site/downloads/"
ssh dave@HOST "rm /data/game-web/site/downloads/Dynasty-build-<OLD>.zip"
```

- Files from the example page, such as `css/` or `images/logo.png`, are not used by the new page. They stay until you delete them.

## 3. Check it (read-only, on the game server, for example by Lane B on David4)

```
cd /data/game-web/site
ls -l index.html files.sha256 images/hero.jpg fonts downloads
sha256sum -c files.sha256                                        # every line OK
grep -o 'SHA-256 <code>[0-9a-f]*' index.html; grep downloads/ files.sha256   # the same hash on the page and for the zip
find index.html files.sha256 images fonts downloads \( -type f ! -perm -o=r \) -o \( -type d ! -perm -o=rx \)   # prints nothing: all readable
grep -oE '(href|src)="/[^"]*"|url\("/[^"]*"\)' index.html | sed -E 's/^(href|src)="//; s/^url\("//; s/"\)?$//' | sort -u |
  while read u; do f=".$u"; case "$u" in */) f="${f}index.html";; esac; [ -f "$f" ] && echo "ok $u" || echo "MISSING $u"; done   # every link ok
curl -s -o /dev/null -w '%{http_code}\n' https://hannibalshouse.duckdns.org/                 # 401: the login is still on
```

Then one person logs in from a phone on mobile data, sees the page, and starts the download.
