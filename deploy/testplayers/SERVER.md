# The test players' page on Dave's web server

Dave set up the web server on 22 Nov 2026. It is Caddy in Docker on the Ubuntu game server **dell-gameserver-01**, the same computer as David4.
- Address: https://hannibalshouse.duckdns.org/
- Login: HTTPS and a login for the four test players are already set up there, for the whole site.
- Site root: `/data/game-web/site/` on the host. It belongs to dave, and the container reads it as `/srv`.

On 23 Nov Dave asked that people who log in land straight on the test players' page, so the page is the site's `index.html`. The only change to the server's settings is one optional line in step 3. Nothing here touches its compose file, the login or the certificates.

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
| `files.sha256` | the SHA-256 of every other file |

All the page's links start with `/`. File names have no spaces.

## 2. Copy it up (Dave, one paste in PowerShell on his PC)

Set the build number on the first line. If the name `dell-gameserver-01` does not resolve from the PC, put the server's LAN address there instead. Type the password when scp asks, or use your SSH key. No password goes in any file.

```
$build = "<N>"; $server = "dell-gameserver-01"
Set-Location "E:\Software\godotDev\dynasty_export\build-$build\site"; scp -r index.html files.sha256 images fonts downloads "dave@${server}:/data/game-web/site/"
```

- scp makes `images/`, `fonts/` and `downloads/` if they are not there yet. It replaces only files with the same names, so `index.html` (the example page) is replaced and the build's zip is added. It deletes nothing. Caddy picks up the change without a restart.
- **Older zips stay** in `downloads/` until you remove them. The four testers can see them, because `/downloads/` shows a file list. To remove one:

```
ssh "dave@${server}" "ls -l /data/game-web/site/downloads/; rm /data/game-web/site/downloads/Dynasty-build-<OLD>.zip"
```

- Files from the example page, such as `css/` or `images/logo.png`, are not used by the new page. They stay until you delete them.

## 3. Show who is logged in (one Caddyfile line, once)

The page shows the login name at the top right. Caddy fills it in as it sends the page, using its `templates` feature and the `{http.auth.user.id}` value that the login sets (Caddy docs: basic_auth, templates). Until this is on, the page simply hides the name.

1. In `/data/game-web/config/Caddyfile`, inside the `hannibalshouse.duckdns.org { ... }` block, add one line with the word `templates` just above the `file_server browse` line. Change nothing else.
2. Check the file, then apply it:

```
sudo docker exec game-web caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo docker exec game-web caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

- `templates` only works on pages sent as HTML or plain text, so the zip, the picture and the fonts pass through untouched.
- To undo it, delete the line and run the same two commands.

## 4. Check it (Dave, in a browser)

1. Open https://hannibalshouse.duckdns.org/ and log in. The page opens straight away, with the picture and the gold lettering.
2. Your login name shows at the top right. On a phone, it shows above the picture.
3. Press **Download the game**. The zip downloads.
4. In PowerShell, compare the zip's fingerprint with the SHA-256 printed on the page:

```
(Get-FileHash "$env:USERPROFILE\Downloads\Dynasty-build-<N>.zip" -Algorithm SHA256).Hash.ToLower()
```

They must match character for character. `files.sha256` in the site has every file's fingerprint, if anything else looks wrong.
