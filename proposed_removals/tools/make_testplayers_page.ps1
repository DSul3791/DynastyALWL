# The test players' download page for a built release (Dave 22 Nov 2026: a page on his own game server,
# hannibalshouse.duckdns.org/dynasty/testplayers, where test players download the game as a zip). Runs on Dave's PC in PowerShell after
# tools\make_release.ps1 (which also calls it):
#   powershell -ExecutionPolicy Bypass -File tools\make_testplayers_page.ps1 -Out ..\dynasty_export\build-<N>
# Writes <Out>\testplayers\: Dynasty-build-<N>.zip (the installer, zipped: browsers and Windows treat a bare downloaded .exe worse) and
# index.html (deploy/testplayers/index.html with the build, size, date and SHA-256 filled in), hero.jpg and fonts\. Copy that whole folder to the web server
# (deploy/testplayers/HOSTING.md). Nothing is uploaded from here.
param(
	[Parameter(Mandatory = $true)][string]$Out
)
$ErrorActionPreference = "Stop"
$Out = (Resolve-Path -LiteralPath $Out).ProviderPath.TrimEnd('\')
$build = (Split-Path $Out -Leaf) -replace '^build-', ''
$setup = Join-Path $Out "DynastySetup-$build.exe"
if (-not (Test-Path -LiteralPath $setup)) { throw "make_testplayers_page: no $setup; run tools\make_release.ps1 first" }
$template = Join-Path $PSScriptRoot "..\deploy\testplayers\index.html"
$page = Join-Path $Out "testplayers"
if (Test-Path -LiteralPath $page) { Remove-Item -LiteralPath $page -Recurse -Force }
New-Item -ItemType Directory -Force -Path $page | Out-Null

$zipName = "Dynasty-build-$build.zip"
$zip = Join-Path $page $zipName
Write-Host "== zip: $zip"
# Compress-Archive (Windows PowerShell 5.1) takes files under 2 GB; the installer is about 0.8 GB and already compressed, so Fastest.
if ((Get-Item -LiteralPath $setup).Length -ge 2GB) { throw "make_testplayers_page: the installer is over 2 GB; Compress-Archive in Windows PowerShell 5.1 cannot zip it" }
Compress-Archive -LiteralPath $setup -DestinationPath $zip -CompressionLevel Fastest
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
$sizeMb = [int][Math]::Round((Get-Item -LiteralPath $zip).Length / 1MB)
$date = (Get-Date).ToString("d MMMM yyyy", [Globalization.CultureInfo]::InvariantCulture)

$html = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $template).ProviderPath)
$html = $html.Replace("{{BUILD}}", "$build").Replace("{{ZIP}}", $zipName).Replace("{{SHA256}}", $hash).Replace("{{SIZE_MB}}", "$sizeMb").Replace("{{DATE}}", $date).Replace("{{USER}}", "")
if ($html.Contains("{{")) { throw "make_testplayers_page: the page still has a {{...}} field the script does not fill" }
[IO.File]::WriteAllText((Join-Path $page "index.html"), $html)   # UTF-8 without a byte order mark
# The page's picture (cropped from the title painting) and the menu fonts with their licence (SIL OFL 1.1 travels with them).
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "..\deploy\testplayers\hero.jpg") -Destination $page
New-Item -ItemType Directory -Force -Path (Join-Path $page "fonts") | Out-Null
foreach ($f in "Cinzel-Bold.ttf", "EBGaramond-Regular.ttf", "EBGaramond-SemiBold.ttf", "FONTS_LICENSE.md") {
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot "..\assets\ui\fonts\$f") -Destination (Join-Path $page "fonts")
}

Write-Host "make_testplayers_page: $page"
Write-Host "  index.html, hero.jpg, fonts\ and $zipName ($sizeMb MB, SHA-256 $hash)"
Write-Host "  copy this folder to the web server: deploy\testplayers\HOSTING.md"
