# The test players' page on Dave's web server

Dave set up the web server on 22 Nov 2026. It is Caddy in Docker on the Ubuntu game server **dell-gameserver-01**, the same computer as David4.
- Address: https://hannibalshouse.duckdns.org/
- Login: HTTPS and a login for the four test players are already set up there, for the whole site.
- Site root: `/data/game-web/site/` on the host. It belongs to dave, and the container reads it as `/srv`.

On 23 Nov Dave asked that people who log in land straight on the test players' page, so the front page is the site's `index.html`. The only change to the server's settings is one optional line in step 3. Nothing here touches its compose file, the login or the certificates.

**Status: not yet run.** These steps have not been tried on the server.

## 1. Make the site folder (Dave's PC, after `tools\make_release.ps1`)

```
powershell -ExecutionPolicy Bypass -File tools\make_testplayers_site.ps1 -Out ..\dynasty_export\build-<N>
```

It writes `..\dynasty_export\build-<N>\site\`, laid out exactly like `/data/game-web/site/`:

| On the server | Address |
|---|---|
| `index.html` | https://hannibalshouse.duckdns.org/ (the front page: Download latest, Submit a bug, Suggest an idea) |
| `download/index.html` | https://hannibalshouse.duckdns.org/download/ (the zip, and how to install, join and report) |
| `css/site.css`, `images/hero.jpg`, `fonts/` | the look (shared with the bug and idea pages), the picture, and the menu fonts with their licence |
| `downloads/Dynasty-build-<N>.zip` | https://hannibalshouse.duckdns.org/downloads/Dynasty-build-&lt;N&gt;.zip |
| `latest.json` | the build number, zip, size and date, for the testers' bug and idea pages |
| `files.sha256` | the SHA-256 of every other file |

All the page's links start with `/`. File names have no spaces.

## 2. Copy it up (Dave, one paste in PowerShell on his PC)

The site script prints this line with the right folder; paste that, or set the build number on the first line here. If the name `dell-gameserver-01` does not resolve from the PC, put the server's LAN address there instead. Type the password when scp asks, or use your SSH key. No password goes in any file.

```
$build = "<N>"; $server = "dell-gameserver-01"
Set-Location "E:\Software\godotDev\dynasty_export\build-$build\site"; scp -r index.html latest.json files.sha256 download css images fonts downloads "dave@${server}:/data/game-web/site/"
```

- scp makes `download/`, `css/`, `images/`, `fonts/` and `downloads/` if they are not there yet. It replaces only files with the same names, so `index.html` (the example page) is replaced and the build's zip is added. It deletes nothing. Caddy picks up the change without a restart.
- **Older zips stay** in `downloads/` until you remove them. The four testers can see them, because `/downloads/` shows a file list. To remove one:

```
ssh "dave@${server}" "ls -l /data/game-web/site/downloads/; rm /data/game-web/site/downloads/Dynasty-build-<OLD>.zip"
```

- Files from the example page, such as `css/` or `images/logo.png`, are not used by the new page. They stay until you delete them.

## 2b. The bug and idea pages (one paste on the server, every time after step 2)

The bug and idea pages and their small report service come from the "tester bug and idea pages" work (branch `claude/project-thread-sq5q8u`, `deploy/testersite/`). Its install puts its own front page (the same three boxes, now working, with the high scores) over the one from step 2. It also adds the `/api/` part to the Caddyfile, checks it, and puts the old file back if the check fails. It asks once for the GitHub token. Running it again is safe. Until that work is merged, step 2 brings back the "Opening soon" front page, so run this again after every upload:

```
sudo mkdir -p /data/game-web/reports && cd /data/game-web/reports && sudo curl -fsSLO https://raw.githubusercontent.com/DSul3791/DynastyALWL/claude/project-thread-sq5q8u/deploy/testersite/service/install.sh && sudo BRANCH=claude/project-thread-sq5q8u bash install.sh
```

## 3. Show who is logged in (one Caddyfile line, once)

The pages show the login name at the top right. Caddy fills it in as it sends the page, using its `templates` feature and the `{http.auth.user.id}` value that the login sets (Caddy docs: basic_auth, templates). Until this is on, the pages simply hide the name.

1. Keep a copy first: `sudo cp /data/game-web/config/Caddyfile /data/game-web/config/Caddyfile.bak`
2. In `/data/game-web/config/Caddyfile`, inside the `hannibalshouse.duckdns.org { ... }` block, add these two lines just above the `file_server browse` line. Change nothing else.

```
	@home path / /index.html /download/ /download/index.html
	templates @home
```

3. Check that the container sees the new lines, check the file, then apply it:

```
sudo docker exec game-web grep -n templates /etc/caddy/Caddyfile
sudo docker exec game-web caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo docker exec game-web caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

- The first command must print the `templates @home` line. If it prints nothing, the container still has the old file: run `sudo docker restart game-web`.
- `@home` keeps the templates to the two pages. When the bug and idea pages arrive, their paths join that line. The zip, the picture, the fonts and the file list pass through untouched.
- To undo it: `sudo cp /data/game-web/config/Caddyfile.bak /data/game-web/config/Caddyfile`, then run the last two commands.

## 4. Check it (Dave, in a browser)

1. Open https://hannibalshouse.duckdns.org/ and log in. The page opens straight away, with the picture and the gold lettering.
2. Your login name shows at the top right. On a phone, it shows above the picture.
3. Press **Download latest**, then **Download the game**. The zip downloads.
4. In PowerShell, compare the zip's fingerprint with the SHA-256 printed on the page:

```
(Get-FileHash "$env:USERPROFILE\Downloads\Dynasty-build-<N>.zip" -Algorithm SHA256).Hash.ToLower()
```

They must match character for character. If anything else looks wrong, check every file on the server: `cd /data/game-web/site && sha256sum -c files.sha256` (each line says OK).

If scp says "Permission denied" for a folder, that folder belongs to root from the example page: `sudo chown -R dave /data/game-web/site` fixes it.
