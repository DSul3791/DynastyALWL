# First-run checks of a built play-test release, before players get it (gate review of PR #1546; coordinator 22 Nov 2026: nothing may
# wait on a person). Runs on Dave's PC in PowerShell with Docker Desktop, on the folder tools\make_release.ps1 made:
#   powershell -ExecutionPolicy Bypass -File tools\release_first_run.ps1 -Out ..\dynasty_export\build-<N>
# In order, each with a hard time limit that closes whatever it started (a window, the installer, the container):
#   1. installer: DynastySetup-<N>.exe installed silently into <Out>\first_run\install (refused when Dynasty is already installed on
#      this PC: the test install would take over that install's uninstall entry)
#   2. two short starts of the installed game (1200 frames each, a window opens): the default driver, then --rendering-driver d3d12;
#      FAIL when a start has no driver line or used another driver than asked
#   Every game run is judged by what it left, not by its exit code: the exported Windows game ends with OS.kill, which gives exit 0
#   on every path (Z5 review C2; the short starts quit through the engine, so their exit code still counts). A run fails when Windows logged an Application Error for Dynasty.exe while it ran (a crash, also
#   one in the engine's teardown after the game's own quit), and the cold play also fails when its log never reaches the game's
#   "EXIT:" line (it did not quit by its own path, or the log was not flushed before the process ended: Z5 review C3).
#   3. server package: docker load of dynasty-server-build-<N>.tar, then its compose.yaml up as a throwaway project (dynasty-firstrun,
#      host ports 24700/24701, its own volume), waits until the server is running
#   4. cold play: the installed game (fresh profile, Vulkan, 1920x1080 windowed) joins that server by itself (--test: no title or
#      character pages, no character), stands about two minutes and quits; prints the "JOIN: ground ready" line and the longest FREEZE
#   5. compose stop: the server must save and exit 0 inside the 90 s grace; then compose down removes the container and its volume
#   6. uninstall: the installer's own uninstaller, silently; the install folder and the uninstall entry must be gone
# -NoServer skips 3 to 5 (no Docker needed). Logs and the fresh profiles are in <Out>\first_run\. Dave's own game data, his Godot,
# his saves, his own containers and the dynasty_dynasty-data volume are never touched; only Dynasty.exe processes started from
# <Out>\first_run\install are ever closed.
param(
	[Parameter(Mandatory = $true)][string]$Out,
	[switch]$NoServer
)
$ErrorActionPreference = "Stop"
$Out = (Resolve-Path -LiteralPath $Out).ProviderPath.TrimEnd('\')
$build = (Split-Path $Out -Leaf) -replace '^build-', ''
$setup = Join-Path $Out "DynastySetup-$build.exe"
$tar = Join-Path $Out "dynasty-server-build-$build.tar"
$compose = Join-Path $Out "compose.yaml"
$runs = Join-Path $Out "first_run"
$install = Join-Path $runs "install"
$exe = Join-Path $install "Dynasty.exe"
# The AppId of deploy/client/dynasty.iss; a per-user install (PrivilegesRequired=lowest) keeps its uninstall entry here.
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{6B0E5C1E-7D4A-4F55-9C1B-2D7A3E9F4C21}_is1"
$project = "dynasty-firstrun"
$container = "dynasty-firstrun"
$port = 24700   # not 24600: Dave's own Play server may be using it
$script:failed = $false
$script:serverUp = $false
$script:dockerOut = ""

# True while the folder still holds a file. The uninstaller hands over to a copy of itself and returns at once; that copy deletes the
# files one by one and its own unins000 files last, so a check must wait for the folder to empty.
function Has-Files([string]$folder) { [bool](Get-ChildItem -LiteralPath $folder -Recurse -File -Force -ErrorAction SilentlyContinue | Select-Object -First 1) }

function Fail([string]$why) { Write-Host "   FAIL: $why"; $script:failed = $true }

# Starts a program and waits at most $limit seconds; past that it is closed (with everything it started) and that is a FAIL.
# Returns the exit code, or -1 when it had to be closed.
function Run-Limited([string]$file, [string]$arguments, [int]$limit, [string]$what) {
	$p = Start-Process -FilePath $file -ArgumentList $arguments -WorkingDirectory (Split-Path $file -Parent) -PassThru
	$null = $p.Handle   # Windows PowerShell 5.1 gives no ExitCode later without this
	if (-not $p.WaitForExit($limit * 1000)) {
		Fail "$what still running after $limit s; closed"
		& taskkill.exe /PID $p.Id /T /F | Out-Null
		return -1
	}
	return $p.ExitCode
}

# Windows' Application Error events (event 1000, the crash dialog's record) for Dynasty.exe since $since; WER writes them a moment after
# the crash, so this waits a few seconds first. Each one found is a FAIL with its first lines.
function Check-Crashes([string]$what, [datetime]$since) {
	Start-Sleep -Seconds 5
	$events = @(Get-WinEvent -FilterHashtable @{ LogName = "Application"; ProviderName = "Application Error"; StartTime = $since } -ErrorAction SilentlyContinue |
		Where-Object { $_.Message -match "Dynasty\.exe" -and $_.Message -like "*$install*" })   # this run's install only, not another Dynasty on this PC
	foreach ($e in $events) {
		Fail "$what crashed: Windows Application Error at $($e.TimeCreated.ToString('HH:mm:ss')): $((($e.Message -split "`r?`n") | Select-Object -First 3) -join ' | ')"
	}
	if ($events.Count -eq 0) { Write-Host "   no Application Error event for Dynasty.exe" }
}

# The game with a fresh APPDATA, LOCALAPPDATA and TEMP (a first launch on a friend's PC: no shader cache, settings or characters).
function Start-Fresh([string]$name, [string]$engine, [string]$game, [string]$want, [int]$limit, [switch]$NeedExit) {
	$home_dir = Join-Path $runs "$name-profile"
	if (Test-Path -LiteralPath $home_dir) { Remove-Item -LiteralPath $home_dir -Recurse -Force }
	foreach ($d in "Roaming", "Local", "Temp") { New-Item -ItemType Directory -Force -Path (Join-Path $home_dir $d) | Out-Null }
	$log = Join-Path $runs "$name.log"
	if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
	$saved = @($env:APPDATA, $env:LOCALAPPDATA, $env:TEMP, $env:TMP)
	$env:APPDATA = Join-Path $home_dir "Roaming"; $env:LOCALAPPDATA = Join-Path $home_dir "Local"
	$env:TEMP = Join-Path $home_dir "Temp"; $env:TMP = $env:TEMP
	try {
		# Engine options first, the game's own after "--". Start-Process joins the arguments as they are, so the quotes are written in.
		$arguments = "$engine --log-file `"$log`"" + $(if ($game) { " -- $game" } else { "" })
		Write-Host "== $name : Dynasty.exe $arguments (at most $limit s)"
		$since = Get-Date
		$code = Run-Limited $exe $arguments $limit $name
	}
	finally {
		$env:APPDATA = $saved[0]; $env:LOCALAPPDATA = $saved[1]; $env:TEMP = $saved[2]; $env:TMP = $saved[3]
	}
	Write-Host "   exit $code, log $log"
	Check-Crashes $name $since
	if ($NeedExit) {
		$quit = $null
		if (Test-Path -LiteralPath $log) { $quit = Select-String -LiteralPath $log -Pattern "^EXIT: " | Select-Object -Last 1 }
		if ($null -eq $quit) {
			Fail "the log never reaches the game's EXIT: line (no quit by its own path, or the log was cut off); its tail:"
			if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Tail 8 | ForEach-Object { Write-Host "      $_" } }
		}
		else { Write-Host "   $($quit.Line)" }
	}
	$line = $null
	if (Test-Path -LiteralPath $log) { $line = Select-String -LiteralPath $log -Pattern "Using Device" | Select-Object -First 1 }
	if ($null -eq $line) { Fail "no driver line (no log, or the game did not start its renderer)"; return $log }
	Write-Host "   $($line.Line)"
	# The game may fall back to the other driver by itself (project.godot fallback_to_*), so the line must name the one asked for.
	if ($want -and $line.Line -notmatch $want) { Fail "asked for $want, the game used another driver" }
	# A short start quits through the engine (--quit-after), so its exit code is real; the cold play ends with OS.kill (exit 0 always).
	elseif (-not $NeedExit -and $code -ne 0 -and $code -ne -1) { Fail "exit $code" }
	return $log
}

# Docker with a time limit too (a stuck Docker Desktop must not hold the script): returns the exit code, -1 when it had to be stopped.
function Docker-Limited([int]$limit, [string]$what, [string[]]$arguments) {
	$job = Start-Job -ScriptBlock { param($a) & docker @a 2>&1 | ForEach-Object { "$_" }; "EXIT:$LASTEXITCODE" } -ArgumentList (, $arguments)
	if (-not (Wait-Job $job -Timeout $limit)) {
		Stop-Job $job; Remove-Job $job -Force
		Write-Host "   docker $what still running after $limit s; stopped"
		return -1
	}
	$lines = @(Receive-Job $job); Remove-Job $job -Force
	$code = -1
	foreach ($l in $lines) { if ($l -match '^EXIT:(-?\d+)$') { $code = [int]$Matches[1] } else { $script:dockerOut += "$l`n"; Write-Host "   $l" } }
	return $code
}

function Docker([int]$limit, [string]$what, [string[]]$arguments) {
	$code = Docker-Limited $limit $what $arguments
	if ($code -ne 0) { throw "release_first_run: docker $what failed (exit $code)" }
}

function Compose([int]$limit, [string]$what, [string[]]$arguments) {
	Docker $limit "compose $what" (@("compose", "-p", $project, "-f", $compose) + $arguments)
}

# Quiet docker for polling: its output only, at most 30 s.
function Docker-Text([string[]]$arguments) {
	$job = Start-Job -ScriptBlock { param($a) & docker @a 2>$null } -ArgumentList (, $arguments)
	if (-not (Wait-Job $job -Timeout 30)) { Stop-Job $job; Remove-Job $job -Force; return "" }
	$text = "$(Receive-Job $job)"; Remove-Job $job -Force
	return $text.Trim()
}

foreach ($f in @($setup) + $(if ($NoServer) { @() } else { @($tar, $compose) })) {
	if (-not (Test-Path -LiteralPath $f)) { throw "release_first_run: no $f; run tools\make_release.ps1 first" }
}
if (Test-Path -LiteralPath $uninstallKey) {
	# A test install left by a run that was cut off (its finally never ran) is removed; any other install is Dave's own.
	$location = "$((Get-ItemProperty -LiteralPath $uninstallKey -ErrorAction SilentlyContinue).InstallLocation)".TrimEnd('\')
	$leftover = Join-Path $install "unins000.exe"
	if ($location -ieq $install -and (Test-Path -LiteralPath $leftover)) {
		Write-Host "== removing the test install an earlier run left"
		Run-Limited $leftover "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" 300 "the earlier test install's uninstaller" | Out-Null
		$deadline = (Get-Date).AddSeconds(120)
		while (((Test-Path -LiteralPath $uninstallKey) -or (Has-Files $install)) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
	}
}
if (Test-Path -LiteralPath $uninstallKey) {
	throw "release_first_run: Dynasty is installed on this PC (Settings > Apps); a test install would take over its uninstall entry. Uninstall it first, or test on another PC."
}
New-Item -ItemType Directory -Force -Path $runs | Out-Null
# The test server has no password whatever this shell has set (the --test client cannot answer one).
$composeEnv = @{ DYNASTY_TAG = "build-$build"; DYNASTY_PORT = "$port"; DYNASTY_BLOCK_PORT = "$($port + 1)"; DYNASTY_CONTAINER = $container; DYNASTY_SERVER_PASSWORD = "" }
$savedEnv = @{}
foreach ($k in $composeEnv.Keys) { $savedEnv[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $composeEnv[$k]) }

try {
	# 1. installer
	if (Test-Path -LiteralPath $install) { Remove-Item -LiteralPath $install -Recurse -Force }
	Write-Host "== install: $setup into $install"
	$code = Run-Limited $setup "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /TASKS=`"`" /DIR=`"$install`" /LOG=`"$runs\install.log`"" 600 "the installer"
	if ($code -ne 0) { Fail "the installer exit $code (log $runs\install.log)" }
	if (-not (Test-Path -LiteralPath $exe)) { throw "release_first_run: the installer put no Dynasty.exe in $install" }
	foreach ($f in "Dynasty.pck", "libwatercore.windows.template_release.x86_64.dll") {
		if (-not (Test-Path -LiteralPath (Join-Path $install $f))) { Fail "the install has no $f" }
	}
	Write-Host "   installed: $((Get-ChildItem -LiteralPath $install -File).Name -join ', ')"

	# 2. short starts (--quit-after counts frames: 1200 is about 20 s at 60 fps, enough to reach the title page)
	Start-Fresh "default" "--quit-after 1200" "" "" 300 | Out-Null
	Start-Fresh "d3d12" "--rendering-driver d3d12 --quit-after 1200" "" "D3D12|Direct3D" 300 | Out-Null

	if (-not $NoServer) {
		# 3. server package
		Write-Host "== server: docker load -i $tar (also tags it dynasty-server:latest on this PC, as make_release did)"
		Docker 900 "load" @("load", "-i", $tar)
		Write-Host "== server: compose up ($project, ports $port/$($port + 1), its own new volume)"
		$script:serverUp = $true
		Compose 300 "down (an earlier cut-off run)" @("down", "-v", "--timeout", "90")
		Compose 300 "up" @("up", "-d")
		$deadline = (Get-Date).AddMinutes(15)
		$running = $false
		while ((Get-Date) -lt $deadline) {
			$note = Docker-Text @("exec", $container, "sh", "-c", "cat /data/store/server_run.json 2>/dev/null")
			if ($note -match '"state":"running"') { $running = $true; break }
			if ((Docker-Text @("inspect", "-f", "{{.State.Running}}", $container)) -ne "true") { break }
			Start-Sleep -Seconds 5
		}
		if (-not $running) {
			Write-Host (Docker-Text @("logs", "--tail", "40", $container))
			throw "release_first_run: the server did not reach running inside 15 minutes (or stopped); its log is above"
		}
		Write-Host "   server running"

		# 4. cold play: joins by itself and quits after 150 s by the clock (--timeout); --frames is only a backstop
		$log = Start-Fresh "play" "--rendering-driver vulkan --windowed --resolution 1920x1080" "--test --server=127.0.0.1 --port=$port --timeout=150 --frames=200000" "Vulkan" 420 -NeedExit
		$ground = Select-String -LiteralPath $log -Pattern "JOIN: ground ready" -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($ground) { Write-Host "   $($ground.Line)" } else { Fail "the cold play never logged JOIN: ground ready (did not join or land)" }
		$worst = 0
		# "FREEZE gap: N ms" (src/debug/freeze_watch.gd, the main thread's own clock) and the probe's "FREEZE N ms" lines
		foreach ($m in (Select-String -LiteralPath $log -Pattern "^FREEZE (?:gap: )?(\d+) ms" -ErrorAction SilentlyContinue)) {
			$worst = [Math]::Max($worst, [int]$m.Matches[0].Groups[1].Value)
		}
		Write-Host "   longest FREEZE: $(if ($worst -gt 0) { "$worst ms" } else { 'none over 500 ms' })"

		# 5. stop: run_server.sh turns TERM into the server's own save and close
		Write-Host "== server: compose stop (must save and exit 0 inside 90 s)"
		$started = Get-Date
		Compose 150 "stop" @("stop")
		$seconds = [int]((Get-Date) - $started).TotalSeconds
		$exit = Docker-Text @("inspect", "-f", "{{.State.ExitCode}}", $container)
		Write-Host "   stopped in $seconds s, exit $exit"
		Write-Host (Docker-Text @("logs", "--tail", "5", $container))
		if ("$exit" -ne "0") { Fail "the server exit $exit on stop (not a clean save)" }
	}
}
finally {
	foreach ($k in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($k, $savedEnv[$k]) }
	# Nothing is left running: only games started from the test install are closed.
	Get-Process -Name Dynasty -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($install, [StringComparison]::OrdinalIgnoreCase) } |
		ForEach-Object { Write-Host "   closing a leftover game window (pid $($_.Id))"; & taskkill.exe /PID $_.Id /T /F | Out-Null }
	if ($script:serverUp) {
		foreach ($k in $composeEnv.Keys) { [Environment]::SetEnvironmentVariable($k, $composeEnv[$k]) }
		Write-Host "== server: compose down (removes the test container and its volume)"
		$code = Docker-Limited 300 "compose down" @("compose", "-p", $project, "-f", $compose, "down", "-v", "--timeout", "90")
		if ($code -ne 0) { Fail "compose down exit ${code}: the test container $container or its volume may be left (docker compose -p $project down -v)" }
		foreach ($k in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($k, $savedEnv[$k]) }
	}
	# 6. uninstall (also after a failure, so the test install never stays)
	$uninstaller = Join-Path $install "unins000.exe"
	if (Test-Path -LiteralPath $uninstaller) {
		# The game's own crash reports and telemetry (res://crash_reports) go with the install, so keep a copy beside the logs first.
		$reports = Join-Path $install "crash_reports"
		$kept = Join-Path $runs "crash_reports"
		if (Test-Path -LiteralPath $kept) { Remove-Item -LiteralPath $kept -Recurse -Force }
		if (Test-Path -LiteralPath $reports) { Copy-Item -LiteralPath $reports -Destination $kept -Recurse -Force; Write-Host "   the game's crash reports: $kept" }
		Write-Host "== uninstall"
		Run-Limited $uninstaller "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" 300 "the uninstaller" | Out-Null
		$deadline = (Get-Date).AddSeconds(120)
		while ((Has-Files $install) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
		if (Has-Files $install) { Fail "the uninstaller left files in $install after 120 s" }
		elseif (Test-Path -LiteralPath $uninstallKey) { Fail "the uninstaller left the uninstall entry" }
		else { Write-Host "   uninstalled" }
	}
}

if ($script:failed) { Write-Host "release_first_run: FAIL (see above); do not give this build to players"; exit 1 }
Write-Host "release_first_run: ok; record the driver lines, the ground ready line and the longest FREEZE above with the run"
