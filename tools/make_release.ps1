# Makes a play-test release from this checkout (server/client split plan step C3, Dave 22 Nov 2026: friends need an installer to
# play-test): the players' Windows installer and the matching server image, both stamped with the same build number, so the server lets
# exactly this game in. Runs on Dave's PC in PowerShell with Docker Desktop; everything is built inside containers, nothing is installed.
#   cd <a full clone of DynastyALWL at the release commit, normally main>
#   powershell -ExecutionPolicy Bypass -File tools\make_release.ps1            build only
#   powershell -ExecutionPolicy Bypass -File tools\make_release.ps1 -Publish   also make the GitHub Release build-<N> with the installer (gh)
# Output in ..\dynasty_export\build-<N>\: DynastySetup-<N>.exe (for players), dynasty-server-build-<N>.tar plus compose.yaml and SERVER.md
# (for the gaming server: docker load -i ..., then docker compose -f compose.yaml up -d). The first run compiles the engine (deploy/engine,
# roughly 45 to 90 minutes of full CPU); later runs reuse it.
param(
	# The server players see first in the game's server list (src/client/server_list.gd official()). Provisional, coordinator 22 Nov 2026.
	[string]$Official = "hannibalshouse.duckdns.org:24600",
	# Dave's Windows editor (Godot 4.7.2 + Voxel Tools 1.7). With it the game is exported on Windows itself, with a window, so the export
	# shader baker can run (it needs a real renderer: Godot editor/export/shader_baker_export_plugin.cpp); without it the export runs headless
	# in a container and ships no baked shaders (they compile while playing, as in the editor).
	[string]$WindowsEditor = "",
	# The bought animal models (assets/animals, gitignored by licence, decision 83) go into a pack only when this is given (Dave's call).
	[switch]$IncludeAnimals,
	[switch]$Publish
)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

function Run([string]$what, [scriptblock]$command) {
	Write-Host "== $what"
	& $command
	if ($LASTEXITCODE -ne 0) { throw "make_release: $what failed (exit $LASTEXITCODE)" }
}

# A shallow clone counts only the commits it fetched, which would give a smaller build number than the release before (tools/build_stamp.py).
if ((git rev-parse --is-shallow-repository) -eq "true") { throw "make_release: this clone is shallow; run git fetch --unshallow first" }
if (git status --porcelain -- addons assets data scenes src worlds project.godot export_presets.cfg) {
	throw "make_release: the game files have changes not committed; a release is made from a commit"
}

if ((Test-Path assets\animals) -and -not $IncludeAnimals) {
	throw "make_release: assets\animals (the bought models) is in this checkout and would go into a public download; use a fresh clone, or pass -IncludeAnimals once Dave has said yes"
}

$commit = (git rev-parse HEAD).Trim()
$build = [int](git rev-list --count HEAD)
$out = Join-Path (Split-Path (Get-Location) -Parent) "dynasty_export\build-$build"
New-Item -ItemType Directory -Force -Path "$out\engine", "$out\client" | Out-Null
$outFwd = $out.Replace("\", "/")   # buildx takes the folder paths with forward slashes
$env:DOCKER_BUILDKIT = "1"

# The stamp both builds carry (src/shared/build_stamp.gd reads it): the same format as tools/build_stamp.py, written without a BOM.
$stamp = [ordered]@{ build = $build; commit = $commit; date = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ", [Globalization.CultureInfo]::InvariantCulture) }
[IO.File]::WriteAllText((Join-Path (Get-Location) "build_stamp.json"), ($stamp | ConvertTo-Json) + "`n")

try {
	Run "engine and templates (deploy/engine)" { docker buildx build -f deploy/engine/Dockerfile --output "type=local,dest=$outFwd/engine" deploy/engine }
	if ($WindowsEditor) {
		# The same export as deploy/client/Dockerfile, on Windows: the server address and our template are put in for the export only.
		[IO.File]::WriteAllText((Join-Path (Get-Location) "client_config.json"), "{`"official`": `"$Official`"}`n")
		$presets = [IO.File]::ReadAllText((Join-Path (Get-Location) "export_presets.cfg"))
		$presets = ([regex]'(?m)^custom_template/release=""').Replace($presets, "custom_template/release=`"$outFwd/engine/windows_release_x86_64.exe`"", 1)
		[IO.File]::WriteAllText((Join-Path (Get-Location) "export_presets.cfg"), $presets)
		try {
			# The editor is a window program: Start-Process -Wait is what waits for it and gives its exit code. Start-Process joins
			# the arguments as they are, so the quotes are written in. The import's own exit code is not trusted (tools/gate_pc.sh retries it).
			Write-Host "== Windows editor import"
			Start-Process -FilePath $WindowsEditor -ArgumentList "--path . --import" -Wait -NoNewWindow
			Write-Host "== Windows editor export"
			$p = Start-Process -FilePath $WindowsEditor -ArgumentList "--path . --export-release `"Windows Client`" `"$outFwd/client/Dynasty.exe`"" -Wait -PassThru -NoNewWindow
			if ($p.ExitCode -ne 0) { throw "make_release: the Windows export failed (exit $($p.ExitCode))" }
		}
		finally {
			git checkout -- export_presets.cfg
			Remove-Item client_config.json -ErrorAction SilentlyContinue
		}
		foreach ($f in @("Dynasty.exe", "Dynasty.pck", "libwatercore.windows.template_release.x86_64.dll")) {
			if (-not (Test-Path "$out\client\$f")) { throw "make_release: the export has no $f" }
		}
	}
	else {
		Run "Windows game export (deploy/client)" {
			docker buildx build -f deploy/client/Dockerfile --build-context "engine=$outFwd/engine" --build-arg "OFFICIAL=$Official" --output "type=local,dest=$outFwd/client" .
		}
	}

	Copy-Item deploy\client\dynasty.iss $out -Force
	[IO.File]::WriteAllText("$out\build.iss", "#define Build `"$build`"`n")
	# shortcut: Inno Setup 6 under Wine from a community image (amake/innosetup, floating innosetup6 tag); revisit if it breaks or moves.
	Run "installer (Inno Setup)" { docker run --rm -v "${out}:/work" amake/innosetup:innosetup6-bookworm dynasty.iss }
	if (-not (Test-Path "$out\DynastySetup-$build.exe")) { throw "make_release: no DynastySetup-$build.exe in $out" }

	# The server image reuses the engine just built (deploy/server/engine/godot is gitignored) instead of compiling it again.
	Copy-Item "$out\engine\godot" deploy\server\engine\godot -Force
	Run "server image (deploy/server)" {
		docker buildx build --load -f deploy/server/Dockerfile --build-arg "COMMIT=$commit" -t "dynasty-server:build-$build" -t dynasty-server:latest .
	}
	Run "server image file" { docker save "dynasty-server:build-$build" dynasty-server:latest -o "$out\dynasty-server-build-$build.tar" }
	Copy-Item deploy\server\compose.yaml, deploy\server\SERVER.md $out -Force

	if ($Publish) {
		$notes = "Play-test build $build ($commit).`n`nInstall: download DynastySetup-$build.exe and run it. Windows may say it protected your PC (the game is not signed yet): choose More info, then Run anyway. It installs for you only, no administrator needed.`n`nThe game lists the official server first. Everyone must be on the same build: when a new build comes out, install it over this one."
		Run "GitHub Release build-$build" {
			gh release create "build-$build" "$out\DynastySetup-$build.exe" --target $commit --prerelease --title "Dynasty play-test build $build" --notes $notes
		}
	}
}
finally {
	Remove-Item build_stamp.json -ErrorAction SilentlyContinue   # never left behind: an editor run beside it would act as a release
}

Write-Host "make_release: build $build ready in $out"
Write-Host "  players:        DynastySetup-$build.exe"
Write-Host "  gaming server:  dynasty-server-build-$build.tar, compose.yaml (docker load -i dynasty-server-build-$build.tar; docker compose -f compose.yaml up -d)"
