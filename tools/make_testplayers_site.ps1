# The download site for Dave's own web server (23 Nov 2026): Caddy in Docker on dell-gameserver-01, site root /data/game-web/site/ on that
# host, HTTPS and a login for the four test players already set up there (this script never touches its Caddyfile, compose file or login).
# Runs on Dave's PC in PowerShell after tools\make_release.ps1 (the build folder must hold DynastySetup-<N>.exe):
#   powershell -ExecutionPolicy Bypass -File tools\make_testplayers_site.ps1 -Out ..\dynasty_export\build-<N>
# Writes <Out>\site\, laid out exactly like /data/game-web/site/ on the server (Dave 23 Nov: players land on the page as soon as they log in):
#   index.html                        the test players' page, https://hannibalshouse.duckdns.org/
#   images\hero.jpg, fonts\           its picture and the menu fonts with their SIL OFL licence
#   downloads\Dynasty-build-<N>.zip   the installer, zipped, https://hannibalshouse.duckdns.org/downloads/Dynasty-build-<N>.zip
#   files.sha256                      every other file's SHA-256 with its path, for the check on the server (sha256sum -c)
# Copy it up with the scp line it prints (deploy/testplayers/SERVER.md). Nothing is uploaded from here and no password is written anywhere.
# -Repo is the checkout whose deploy\testplayers and assets\ui\fonts are used; by default the one this script sits in.
param(
	[Parameter(Mandatory = $true)][string]$Out,
	[string]$Repo = ""
)
$ErrorActionPreference = "Stop"
if (-not $Repo) { $Repo = Join-Path $PSScriptRoot ".." }
$Repo = (Resolve-Path -LiteralPath $Repo).ProviderPath.TrimEnd('\')
$Out = (Resolve-Path -LiteralPath $Out).ProviderPath.TrimEnd('\')
$build = (Split-Path $Out -Leaf) -replace '^build-', ''
if ($build -notmatch '^\d+$') { throw "make_testplayers_site: $Out is not a build-<N> folder" }
$setup = Join-Path $Out "DynastySetup-$build.exe"
if (-not (Test-Path -LiteralPath $setup)) { throw "make_testplayers_site: no $setup; run tools\make_release.ps1 first" }
$pages = Join-Path $Repo "deploy\testplayers"
foreach ($f in "index.html", "hero.jpg") {
	if (-not (Test-Path -LiteralPath (Join-Path $pages $f))) { throw "make_testplayers_site: no $f in $pages (use -Repo with a checkout that has it)" }
}

$site = Join-Path $Out "site"
if (Test-Path -LiteralPath $site) { Remove-Item -LiteralPath $site -Recurse -Force }
$downloads = Join-Path $site "downloads"
foreach ($d in "images", "fonts", "downloads") { New-Item -ItemType Directory -Force -Path (Join-Path $site $d) | Out-Null }

# The zip: the one make_release already made (testplayers\), or made here from the installer.
$zipName = "Dynasty-build-$build.zip"
$zip = Join-Path $downloads $zipName
$made = Join-Path $Out "testplayers\$zipName"
if (Test-Path -LiteralPath $made) {
	Write-Host "== zip: copying $made"
	Copy-Item -LiteralPath $made -Destination $zip
}
else {
	Write-Host "== zip: $zip"
	# Compress-Archive (Windows PowerShell 5.1) takes files under 2 GB; the installer is about 0.8 GB and already compressed, so Fastest.
	if ((Get-Item -LiteralPath $setup).Length -ge 2GB) { throw "make_testplayers_site: the installer is over 2 GB; Compress-Archive in Windows PowerShell 5.1 cannot zip it" }
	Compress-Archive -LiteralPath $setup -DestinationPath $zip -CompressionLevel Fastest
}
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
$sizeMb = [int][Math]::Round((Get-Item -LiteralPath $zip).Length / 1MB)
$date = (Get-Date).ToString("d MMMM yyyy", [Globalization.CultureInfo]::InvariantCulture)

function Fill([string]$html) {
	$html = $html.Replace("{{BUILD}}", "$build").Replace("{{ZIP}}", $zipName).Replace("{{SHA256}}", $hash).Replace("{{SIZE_MB}}", "$sizeMb").Replace("{{DATE}}", $date)
	if ($html.Contains("{{")) { throw "make_testplayers_site: a page still has a {{...}} field the script does not fill" }
	return $html
}

# The page, with every link from the site root (the server's own layout notes ask for links that begin with "/").
$page = [IO.File]::ReadAllText((Join-Path $pages "index.html"))
$page = $page.Replace('href="{{ZIP}}"', 'href="/downloads/{{ZIP}}"').Replace('src="hero.jpg"', 'src="/images/hero.jpg"').Replace('url("fonts/', 'url("/fonts/')
foreach ($want in 'href="/downloads/{{ZIP}}"', 'src="/images/hero.jpg"', 'url("/fonts/Cinzel-Bold.ttf")') {
	if (-not $page.Contains($want)) { throw "make_testplayers_site: deploy\testplayers\index.html changed; the page has no $want after the link rewrite" }
}
$utf8 = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without a byte order mark
[IO.File]::WriteAllText((Join-Path $site "index.html"), (Fill $page), $utf8)
Copy-Item -LiteralPath (Join-Path $pages "hero.jpg") -Destination (Join-Path $site "images")
foreach ($f in "Cinzel-Bold.ttf", "EBGaramond-Regular.ttf", "EBGaramond-SemiBold.ttf", "FONTS_LICENSE.md") {
	Copy-Item -LiteralPath (Join-Path $Repo "assets\ui\fonts\$f") -Destination (Join-Path $site "fonts")
}

# Every file's SHA-256 with its path from the site root, in sha256sum's format (LF), so the server check is: sha256sum -c.
$lines = New-Object System.Collections.Generic.List[string]
foreach ($file in Get-ChildItem -LiteralPath $site -Recurse -File | Sort-Object FullName) {
	$rel = $file.FullName.Substring($site.Length + 1).Replace('\', '/')
	$lines.Add(((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()) + "  " + $rel)
}
[IO.File]::WriteAllText((Join-Path $site "files.sha256"), (($lines -join "`n") + "`n"), $utf8)

Write-Host "make_testplayers_site: $site"
Write-Host "  index.html, images\hero.jpg, fonts\, files.sha256, downloads\$zipName ($sizeMb MB, SHA-256 $hash)"
Write-Host "  copy it up (type the password when asked; HOST = dell-gameserver-01 or its LAN address):"
Write-Host "  scp -r `"$site\index.html`" `"$site\files.sha256`" `"$site\images`" `"$site\fonts`" `"$site\downloads`" dave@HOST:/data/game-web/site/"
