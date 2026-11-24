# Times prebuild_ground.gd --processes at several copy counts on the same slice of tile 3,4 (Dave 24 Nov 2026: "lets run a test and try
# running 10,9,8,7,6,5,4 copies and timing stuff all while I watch a tv show"). Each step builds a fresh throwaway folder, announces its
# start and end with the clock time, and adds a line to sweep.log; the folder is deleted after its step. Unattended; no window opens.
#
#   powershell -ExecutionPolicy Bypass -File tools\prebuild_sweep.ps1 -Godot <godot.exe> -Project <clone> [-Out E:\Software\godotDev\prebuild_sweep] [-Counts 10,9,8,7,6,5,4] [-Size 3072]
param(
	[Parameter(Mandatory = $true)][string]$Godot,
	[Parameter(Mandatory = $true)][string]$Project,
	[string]$Out = "E:\Software\godotDev\prebuild_sweep",
	[int[]]$Counts = @(10, 9, 8, 7, 6, 5, 4),
	[int]$Size = 3072
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$log = Join-Path $Out "sweep.log"

function Say([string]$text) {
	$line = "{0}  {1}" -f (Get-Date -Format "HH:mm:ss"), $text
	Write-Output $line
	Add-Content -Path $log -Value $line
}

Say ("sweep: {0} copies in turn, slice x 55296 z 69632, {1} m square of tile 3_4, every detail level and the plants" -f ($Counts -join ","), $Size)

foreach ($n in $Counts) {
	$dir = Join-Path $Out ("copies_{0}" -f $n)
	if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
	$stepLog = Join-Path $Out ("copies_{0}.log" -f $n)
	Say ("START {0} copies" -f $n)
	$t0 = Get-Date
	& $Godot --headless --path $Project --script res://src/worldgen/tools/prebuild_ground.gd -- --tiles=3_4 --area=55296,69632,$Size --processes=$n --out=$dir *> $stepLog
	$seconds = ((Get-Date) - $t0).TotalSeconds
	$done = Select-String -Path $stepLog -Pattern "prebuild_ground: DONE (\d+) blocks" | Select-Object -Last 1
	if ($done) {
		$blocks = [int]$done.Matches[0].Groups[1].Value
		Say ("END   {0} copies: {1:N0} s, {2} blocks, {3:N0} blocks/s" -f $n, $seconds, $blocks, ($blocks / $seconds))
	} else {
		Say ("END   {0} copies: FAILED after {1:N0} s (see {2})" -f $n, $seconds, $stepLog)
	}
	if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
}
Say "sweep: finished"
