# Makes a play-test release from this checkout (server/client split plan step C3, Dave 22 Nov 2026: friends need an installer to
# play-test): the players' Windows installer and the matching server image, both stamped with the same build number, so the server lets
# exactly this game in. Runs on Dave's PC in PowerShell with Docker Desktop; everything is built inside containers, nothing is installed
# (with -WindowsEditor the game export runs in Dave's own editor instead). Use a clone made for releases: the import may touch its files.
#   cd <a full clone of DynastyALWL at the release commit, normally main>
#   powershell -ExecutionPolicy Bypass -File tools\make_release.ps1            build only
#   powershell -ExecutionPolicy Bypass -File tools\make_release.ps1 -Publish   also a PUBLIC GitHub Release build-<N> with the installer (gh);
#       only on Dave's explicit yes (public repo, the installer holds the bought animal models; Dave 22 Nov 2026)
# Output in ..\dynasty_export\build-<N>\: DynastySetup-<N>.exe (for players; site\ holds it zipped with the testers' pages),
# dynasty-server-build-<N>.tar plus compose.yaml and SERVER.md
# (for the gaming server: docker load -i ..., then docker compose -f compose.yaml up -d). The first run compiles the engine (deploy/engine,
# roughly 45 to 90 minutes of full CPU); later runs reuse it.
param(
	# The server players see first in the game's server list (src/client/server_list.gd official()). Dave 22 Nov 2026: hannibalshouse.duckdns.org is where the server will be.
	[string]$Official = "hannibalshouse.duckdns.org:24600",
	# Dave's Windows editor (Godot 4.7.2 + Voxel Tools 1.7). With it the game is exported on Windows itself, with a window, so the export
	# shader baker can run (it needs a real renderer: Godot editor/export/shader_baker_export_plugin.cpp); without it the export runs headless
	# in a container and ships no baked shaders (they compile while playing, as in the editor).
	[string]$WindowsEditor = "",
	# The bought animal models (assets/animals) go into the game's pack (Dave 22 Nov 2026: "incorporated right in with the game"). Since
	# 23 Nov 2026 they are in the repository through Git LFS; a clone without them (older commits) copies them, read only, from Dave's game
	# folder, which is never changed.
	[string]$AnimalsFrom = "",
	# A build without them (the game draws its code-built animals instead).
	[switch]$NoAnimals,
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

$tracked = @(git -c core.quotepath=off ls-files -- assets/animals)
if ($NoAnimals) {
	if (Test-Path assets\animals) { throw "make_release: -NoAnimals, but assets\animals is in this checkout; use a clone made with tools/skip_models.sh" }
}
elseif ($tracked.Count -gt 0) {
	# The models are in the repository (Git LFS): this clone must hold the real files, not LFS pointer stubs (git lfs pull) and not a
	# sparse checkout without them (tools/skip_models.sh).
	if ($AnimalsFrom) { throw "make_release: the animal models are in the repository now; leave out -AnimalsFrom" }
	$missing = @($tracked | Where-Object { -not (Test-Path -LiteralPath $_) })
	if ($missing.Count -gt 0) { throw "make_release: $($missing.Count) model files are not in this checkout (sparse checkout?); run: git sparse-checkout disable; git lfs pull" }
	$stubs = @($tracked | Where-Object { (Get-Item -LiteralPath $_).Length -lt 1024 -and (Get-Content -LiteralPath $_ -TotalCount 1 -ErrorAction SilentlyContinue) -like "version https://git-lfs*" })
	if ($stubs.Count -gt 0) { throw "make_release: $($stubs.Count) model files are LFS pointers, not the models; run: git lfs pull" }
	Write-Host "== animal models: $($tracked.Count) files from the repository"
}
else {
	if (-not $AnimalsFrom) { $AnimalsFrom = "C:\GodotProjects\DynastyALWL\assets\animals" }
	# Fail loudly rather than ship the plain animals by mistake.
	if (-not (Get-ChildItem -LiteralPath $AnimalsFrom -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1)) {
		throw "make_release: no animal models in $AnimalsFrom; pass -AnimalsFrom <folder> or -NoAnimals"
	}
	# This clone's copy is deleted before each copy, so it must never be Dave's folder itself: not the same path (any case or trailing
	# slash) and not a link (a junction or symlink would let the delete reach through to the source).
	$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $AnimalsFrom).ProviderPath).TrimEnd('\')
	$mine = [IO.Path]::GetFullPath((Join-Path (Get-Location).ProviderPath "assets\animals")).TrimEnd('\')
	if ($source -ieq $mine) { throw "make_release: -AnimalsFrom is this clone's own folder" }
	if (Test-Path -LiteralPath $mine) {
		if ((Get-Item -LiteralPath $mine -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
			throw "make_release: $mine is a link; remove the link by hand (not its contents) and run again"
		}
		Remove-Item -LiteralPath $mine -Recurse -Force   # this clone's own copy from an earlier run
	}
	Write-Host "== animal models: copying from $source (read only)"
	Copy-Item -LiteralPath $source -Destination $mine -Recurse
	$count = (Get-ChildItem -LiteralPath $mine -Recurse -File).Count
	Write-Host "   $count files"
}
# The island water record (gitignored bake input, ~90 MB a tile) would match the export's include filter; a fresh clone has none.
if (Test-Path worlds\*\record) { throw "make_release: a world record folder (worlds\*\record) is in this checkout; use a fresh clone" }

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
		$here = (Get-Location).Path
		$project = $here.Replace("\", "/")
		$log = "$outFwd/export.log"
		try {
			[IO.File]::WriteAllText((Join-Path $here "client_config.json"), "{`"official`": `"$Official`"}`n")
			$presets = [IO.File]::ReadAllText((Join-Path $here "export_presets.cfg"))
			$presets = ([regex]'(?m)^custom_template/release=""').Replace($presets, "custom_template/release=`"$outFwd/engine/windows_release_x86_64.exe`"", 1)
			[IO.File]::WriteAllText((Join-Path $here "export_presets.cfg"), $presets)
			# The editor is a window program: Start-Process -Wait is what waits for it and gives its exit code. Start-Process joins the
			# arguments as they are, so the quotes are written in. A first import can fail and pass the second time (tools/gate_pc.sh).
			foreach ($try in 1, 2) {
				Write-Host "== Windows editor import ($try)"
				$p = Start-Process -FilePath $WindowsEditor -WorkingDirectory $here -ArgumentList "--path `"$project`" --import --log-file `"$log`"" -Wait -PassThru -NoNewWindow
				if ($p.ExitCode -eq 0) { break }
			}
			Write-Host "== Windows editor export"
			$p = Start-Process -FilePath $WindowsEditor -WorkingDirectory $here -ArgumentList "--path `"$project`" --export-release `"Windows Client`" `"$outFwd/client/Dynasty.exe`" --log-file `"$log`"" -Wait -PassThru -NoNewWindow
			if ($p.ExitCode -ne 0) {
				if (Test-Path "$out\export.log") { Get-Content "$out\export.log" -Tail 40 }
				throw "make_release: the Windows export failed (exit $($p.ExitCode)); log $out\export.log"
			}
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
	# The testers' site with the zipped installer (Dave 22-23 Nov 2026; deploy/testplayers/SERVER.md puts it on his web server).
	& (Join-Path $PSScriptRoot "make_testplayers_site.ps1") -Out $out

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
Write-Host "  players:        site\ (the testers' site with downloads\Dynasty-build-$build.zip; deploy\testplayers\SERVER.md), or DynastySetup-$build.exe"
Write-Host "  gaming server:  dynasty-server-build-$build.tar, compose.yaml (docker load -i dynasty-server-build-$build.tar; docker compose -f compose.yaml up -d)"
