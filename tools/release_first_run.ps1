# First-run checks of a built play-test game, before players get it (gate review of PR #1546, 22 Nov 2026): the Windows template is
# built with Direct3D 12 but nothing else proves D3D12 is in it. Runs the exported Dynasty.exe on Dave's PC with a fresh APPDATA,
# LOCALAPPDATA and TEMP (a first launch on a friend's PC: no shader cache, no settings, no characters), each run with its own log.
#   powershell -ExecutionPolicy Bypass -File tools\release_first_run.ps1 -Exe <...\dynasty_export\build-N\client\Dynasty.exe>
#       two short starts (about 20 s each, a window opens): the default driver, then --rendering-driver d3d12; prints each driver line
#   ... -Play
#       then one cold play (Vulkan, 1920x1080 windowed) that runs until the window is closed, for the lag thread's longest FREEZE and
#       ground-ready times; its log is play.log
# Logs and the fresh folders are in <exe folder>\..\first_run\; Dave's own game data is never touched.
param(
	[Parameter(Mandatory = $true)][string]$Exe,
	[switch]$Play
)
$ErrorActionPreference = "Stop"
$Exe = (Resolve-Path $Exe).Path
$out = Join-Path (Split-Path (Split-Path $Exe -Parent) -Parent) "first_run"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Start-Fresh([string]$name, [string]$arguments) {
	$home_dir = Join-Path $out "$name-profile"
	if (Test-Path $home_dir) { Remove-Item $home_dir -Recurse -Force }
	foreach ($d in "Roaming", "Local", "Temp") { New-Item -ItemType Directory -Force -Path (Join-Path $home_dir $d) | Out-Null }
	$log = Join-Path $out "$name.log"
	# The child takes this session's environment: a profile nobody has used, so caches and settings start empty.
	$saved = @($env:APPDATA, $env:LOCALAPPDATA, $env:TEMP, $env:TMP)
	$env:APPDATA = Join-Path $home_dir "Roaming"; $env:LOCALAPPDATA = Join-Path $home_dir "Local"
	$env:TEMP = Join-Path $home_dir "Temp"; $env:TMP = $env:TEMP
	try {
		Write-Host "== $name : $Exe $arguments"
		$p = Start-Process -FilePath $Exe -ArgumentList "$arguments --log-file `"$log`"" -WorkingDirectory (Split-Path $Exe -Parent) -Wait -PassThru
	}
	finally {
		$env:APPDATA = $saved[0]; $env:LOCALAPPDATA = $saved[1]; $env:TEMP = $saved[2]; $env:TMP = $saved[3]
	}
	Write-Host "   exit $($p.ExitCode), log $log"
	if (Test-Path $log) {
		# Godot's start line names the driver and the GPU, e.g. "Vulkan 1.3.x - Forward+ - Using Device #0: ..." or "D3D12 ... - Using Device".
		Select-String -Path $log -Pattern "Using Device|Vulkan|D3D12|Direct3D|OpenGL|rendering driver" | Select-Object -First 4 | ForEach-Object { Write-Host "   $($_.Line)" }
	}
	else { Write-Host "   no log written" }
}

# --quit-after counts frames: about 20 s at 60 fps, enough to reach the title page.
Start-Fresh "default" "--quit-after 1200"
Start-Fresh "d3d12" "--rendering-driver d3d12 --quit-after 1200"
if ($Play) { Start-Fresh "play" "--rendering-driver vulkan --windowed --resolution 1920x1080" }
Write-Host "release_first_run: record the two driver lines above (and the play.log FREEZE / ground-ready lines) in the release notes of the run"
