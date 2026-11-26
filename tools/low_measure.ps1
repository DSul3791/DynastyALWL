# Low-settings measure on Lane A (Windows, PowerShell): a local server and three client plays held to chosen cores.
# Plays: m8 (the Measure this machine table, client on 4 cores with both threads), m4 (the table, 4 cores one thread each),
# r4 (the robot route at Low, 4 cores one thread each). The server runs on two other cores (a tester's server is remote).
# Run from the lane's own clone, with Dave's Godot and installed game closed:
#   powershell -ExecutionPolicy Bypass -File tools\low_measure.ps1 -Exe C:\DynastyLane\godot\godot_lane_a.exe
# -Plays m8 runs only that play. A play that has not joined within -JoinLimit seconds, or runs past -PlayLimit, stops the WHOLE run at once. Every process
# this script started is closed on exit, also on an error or Ctrl+C. Logs: $Out\<play>.log, server.log, machine_run_<play>.txt.

param(
	[Parameter(Mandatory = $true)][string]$Exe,
	[string]$Out = "C:\DynastyLane\lane_low",
	[int]$Port = 24710,
	[int]$JoinLimit = 240,
	[int]$PlayLimit = 900,
	[string[]]$Plays = @("m8", "m4", "r4")
)

$ErrorActionPreference = "Stop"
# powershell -File passes "-Plays m8,m4" as one string: split it here.
$Plays = @($Plays | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
$known = @("m8", "m4", "r4")

if (@($Plays | Where-Object { $known -notcontains $_ }).Count -gt 0 -or $Plays.Count -eq 0) {
	Write-Output "LOW MEASURE STOPPED: -Plays must be some of m8, m4, r4 (got: $($Plays -join ', '))"
	exit 1
}
$started = @()

function Stop-Started {
	foreach ($p in $script:started) {
		if ($p -and -not $p.HasExited) {
			Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
		}
	}
}

try {
	$Out = [IO.Path]::GetFullPath($Out)
	$Exe = [IO.Path]::GetFullPath($Exe)

	# Fresh folders every run: an old cache or store would change what is measured.
	if ((Split-Path $Out -Leaf) -notmatch '^lane_[A-Za-z0-9_]+$') { throw "-Out must be a lane folder named lane_... (it is emptied first): $Out" }

	if (Test-Path -LiteralPath $Out) { Remove-Item -LiteralPath $Out -Recurse -Force }
	New-Item -ItemType Directory -Force "$Out\store", "$Out\cache" | Out-Null
	$cache = ($Out + "\cache") -replace "\\", "/"
	$store = ($Out + "\store") -replace "\\", "/"

	$srv = Start-Process $Exe -ArgumentList '--headless', '--path', '.', 'res://scenes/terrain_server/terrain_server.tscn', '--', "--port=$Port", "--store=$store", '--open-admin' -RedirectStandardOutput "$Out\server.log" -RedirectStandardError "$Out\server_err.log" -PassThru
	$started += $srv
	$srv.ProcessorAffinity = 0xF00
	Start-Sleep 60

	if ($srv.HasExited) { throw "the server stopped while starting (see $Out\server_err.log)" }

	$playList = @(
		@{ Name = "m8"; Mask = 0x0FF; Args = @('--robot-plan=measure') },
		@{ Name = "m4"; Mask = 0x055; Args = @('--robot-plan=measure') },
		@{ Name = "r4"; Mask = 0x055; Args = @('--robot-plan=route', '--quality=0') }
	)

	foreach ($play in ($playList | Where-Object { $Plays -contains $_.Name })) {
		$n = $play.Name
		$log = "$Out\$n.log"
		$all = @('--path', '.', '--resolution', '1920x1080', 'res://scenes/terrain_client/terrain_client.tscn', '--', '--server=127.0.0.1', "--port=$Port", "--cache=$cache", '--robot=Robot_1', '--robot-admin', "--timeout=$PlayLimit") + $play.Args
		$c = Start-Process $Exe -ArgumentList $all -RedirectStandardOutput $log -RedirectStandardError "$Out\${n}_err.log" -PassThru
		$started += $c
		$c.ProcessorAffinity = $play.Mask
		$t0 = Get-Date
		$joined = $false

		while (-not $c.HasExited) {
			Start-Sleep 5
			$age = ((Get-Date) - $t0).TotalSeconds

			if (-not $joined -and (Test-Path $log) -and (Select-String -Path $log -Pattern "step joined" -Quiet)) { $joined = $true }

			if (-not $joined -and $age -gt $JoinLimit) { throw "play $n did not join within $JoinLimit s (see $log)" }

			if ($age -gt $PlayLimit + 60) { throw "play $n ran past $PlayLimit s (see $log)" }
		}

		if (-not $joined) { throw "play $n ended without joining (see $log)" }

		$run = Join-Path $env:APPDATA "Godot\app_userdata\Dynasty a life well lived\machine_run.txt"

		if ($n -like "m*") {
			if (-not (Test-Path -LiteralPath $run) -or (Get-Item -LiteralPath $run).LastWriteTime -lt $t0) { throw "play $n ended without a new measure table (see $log)" }

			Copy-Item -LiteralPath $run "$Out\machine_run_$n.txt" -Force
			$gpuRun = Join-Path (Split-Path $run) "gpu_probe.txt"

			if ((Test-Path -LiteralPath $gpuRun) -and (Get-Item -LiteralPath $gpuRun).LastWriteTime -ge $t0) { Copy-Item -LiteralPath $gpuRun "$Out\gpu_probe_$n.txt" -Force }
		}

		Write-Output "play $n done ($([int]((Get-Date) - $t0).TotalSeconds) s)"
	}

	Write-Output "LOW MEASURE DONE: logs in $Out"
}
catch {
	Write-Output "LOW MEASURE STOPPED: $_"
	exit 1
}
finally {
	Stop-Started
}
