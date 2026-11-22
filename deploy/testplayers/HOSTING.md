# The test players' download page on the game server

On 22 Nov 2026 Dave decided that test players download the game as a zip from a page on his own game server, at **https://hannibalshouse.duckdns.org/dynasty/testplayers/**. A public GitHub Release stays off.

**Status: not yet run.** These steps have not been tried on his server.

## What you put up

`tools\make_release.ps1` writes a ready folder, `..\dynasty_export\build-<N>\testplayers\`, holding:
- `index.html`, the page, with `hero.jpg` and `fonts\`. It has the build number, the download button, the install steps (including Windows' "More info, then Run anyway"), how to join and where to report.
- `Dynasty-build-<N>.zip`, with the installer inside. Its size and SHA-256 are printed on the page.

For a build that already exists, make the folder on its own:

```
powershell -ExecutionPolicy Bypass -File tools\make_testplayers_page.ps1 -Out ..\dynasty_export\build-<N>
```

**Anyone with the link can download the game.** That stays true unless you turn on the password in step 4. The game includes the bought animal models.

## Option A: a small web container (Caddy), if the server has no web server yet

This runs next to the game server's own `compose.yaml` and needs nothing else installed.

1. On the game server, make a folder (for example `dynasty-web`). Copy into it `compose.web.yaml` and `Caddyfile` from `deploy/testplayers/`, and the `testplayers` folder from the build.
2. On the router, forward TCP **80** and **443** to the game server. Caddy uses port 80 to prove to Let's Encrypt that it owns `hannibalshouse.duckdns.org`, then gets and renews the HTTPS certificate by itself. The game ports UDP 24600 and TCP 24601 stay as they are.
3. In that folder, start it: `docker compose -f compose.web.yaml up -d`. Then `docker logs dynasty-web` should show the certificate being obtained. Open https://hannibalshouse.duckdns.org/dynasty/testplayers/ from a phone on mobile data to check it.
4. Optional password: make a hash with `docker run --rm caddy:2.8 caddy hash-password --plaintext "the password"`. In `Caddyfile`, remove the `#` in front of the three `basic_auth` lines, and replace `PASTE_THE_HASH_HERE` with the hash. Then run `docker restart dynasty-web`. Testers then log in as `tester` with that password.
5. A new build: replace the `testplayers` folder with the new one. No restart is needed.

## Option B: nginx is already running

Copy the build's `testplayers` folder to `/var/www/dynasty/testplayers` and add this inside the `server { ... }` block for hannibalshouse.duckdns.org:

```
location /dynasty/testplayers/ {
    alias /var/www/dynasty/testplayers/;
    index index.html;
    # Optional password: sudo htpasswd -c /etc/nginx/dynasty.htpasswd tester   (apache2-utils), then remove the two # below
    # auth_basic "Dynasty test players";
    # auth_basic_user_file /etc/nginx/dynasty.htpasswd;
}
```

Then run `sudo nginx -t && sudo systemctl reload nginx`. For HTTPS, if that site has none yet, use `sudo certbot --nginx -d hannibalshouse.duckdns.org`. Forward ports 80 and 443 as in Option A.

## Option C: Apache is already running

Copy the folder to `/var/www/dynasty/testplayers` and add this to the hannibalshouse.duckdns.org site:

```
Alias /dynasty/testplayers /var/www/dynasty/testplayers
<Directory /var/www/dynasty/testplayers>
    Require all granted
    DirectoryIndex index.html
    # Optional password: sudo htpasswd -c /etc/apache2/dynasty.htpasswd tester, then replace "Require all granted" above with these four lines:
    # AuthType Basic
    # AuthName "Dynasty test players"
    # AuthUserFile /etc/apache2/dynasty.htpasswd
    # Require valid-user
</Directory>
```

Then run `sudo apachectl configtest && sudo systemctl reload apache2`. For HTTPS, use `sudo certbot --apache -d hannibalshouse.duckdns.org`.

## Windows on the game server

If the game server runs Windows with Docker Desktop, Option A works the same way. Run the commands in PowerShell in that folder. Also allow ports 80 and 443 in Windows Firewall, because Docker Desktop usually asks the first time.
