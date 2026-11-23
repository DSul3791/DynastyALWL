# The test players' page on Dave's web server

Dave set up the web server on 22 Nov 2026. It is Caddy in Docker on the Ubuntu game server **dell-gameserver-01** (LAN address 192.168.0.108; the name does not resolve from Dave's PC, so the copy commands use the address), the same computer as David4.
- Address: https://hannibalshouse.duckdns.org/
- Login: HTTPS and a login for the four test players are already set up there, for the whole site.
- Site root: `/data/game-web/site/` on the host. It belongs to dave, and the container reads it as `/srv`.

On 23 Nov Dave asked that people who log in land straight on the test players' page, so the front page is the site's `index.html`. The only changes to the server's Caddyfile are made by step 2b's install, which checks them and puts the old file back on a failure. Nothing here touches the compose file, the login or the certificates.

**Status: not yet run.** These steps have not been tried on the server.

## 1. Make the site folder (Dave's PC, after `tools\make_release.ps1`)

```
powershell -ExecutionPolicy Bypass -File tools\make_testplayers_site.ps1 -Out ..\dynasty_export\build-<N>
```

It writes `..\dynasty_export\build-<N>\site\`, laid out exactly like `/data/game-web/site/`:

| On the server | Address |
|---|---|
| `index.html`, `bug.html`, `idea.html`, `css/dynasty.css`, `js/tester.js` | the testers' own pages (`deploy/testersite/site/`): the front page https://hannibalshouse.duckdns.org/ (Download latest, Submit a bug, Suggest an idea, high scores) and the bug and idea forms |
| `download/index.html` | https://hannibalshouse.duckdns.org/download/ (the zip, and how to install, join and report) |
| `images/hero.jpg`, `fonts/` | the picture, and the menu fonts with their licence |
| `downloads/Dynasty-build-<N>.zip` | https://hannibalshouse.duckdns.org/downloads/Dynasty-build-&lt;N&gt;.zip |
| `latest.json` | the build number, zip, size and date, for the testers' bug and idea pages |
| `files.sha256` | the SHA-256 of every other file |

All the page's links start with `/`. File names have no spaces.

## 2. Copy it up (Dave, one paste in PowerShell on his PC)

The site script prints this line with the right folder and every top-level item of the site; paste that one (the line below is the same). Type the password when scp asks, or use your SSH key. No password goes in any file.

```
$build = "<N>"; $server = "192.168.0.108"
Set-Location "E:\Software\godotDev\dynasty_export\build-$build\site"; scp -r bug.html css download downloads files.sha256 fonts idea.html images index.html js latest.json "dave@${server}:/data/game-web/site/"
```

- scp makes the folders if they are not there yet. It replaces only files with the same names, so `index.html` (the example page) is replaced and the build's zip is added. It deletes nothing. Caddy picks up the change without a restart.
- **Older zips stay** in `downloads/` until you remove them. The four testers can see them, because `/downloads/` shows a file list. To remove one:

```
ssh "dave@${server}" "ls -l /data/game-web/site/downloads/; rm /data/game-web/site/downloads/Dynasty-build-<OLD>.zip"
```

- Files from the example page, such as `images/logo.png`, and `css/site.css` from earlier uploads are not used any more. They stay until you delete them.

## 2b. The bug and idea service (one paste on the server, once)

The bug and idea pages send their reports through a small report service (`deploy/testersite/`, merged in #1609 as da9574ab; `deploy/testersite/INSTALL.md`). Its install starts that service, adds the `/api/` part and the login-name lines to the Caddyfile, checks it, and puts the old file back if the check fails. It asks once for the GitHub token. Running it again is safe, and it is only needed again when the service itself changes, not for a new build:

```
sudo mkdir -p /data/game-web/reports && cd /data/game-web/reports && sudo curl -fsSLO https://raw.githubusercontent.com/DSul3791/DynastyALWL/da9574abcd98cd05f1ba16b8c8d36dca99672595/deploy/testersite/service/install.sh && sudo BRANCH=da9574abcd98cd05f1ba16b8c8d36dca99672595 bash install.sh
```

## 3. Show who is logged in (done by step 2b)

The pages show the login name at the top right. Step 2b's install adds the two Caddyfile lines for it, once, if the Caddyfile has no `templates` line yet; nothing to do by hand. For the record, the lines it adds just above `file_server browse` are:

```
	@home path / /index.html /download/ /download/index.html
	templates @home
```

They keep Caddy's templates to the two pages, so the zip, the pictures, the fonts and the file list pass through untouched. To undo them by hand, delete the two lines, then run `sudo docker exec game-web caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile` and `sudo docker exec game-web caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile`.

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
