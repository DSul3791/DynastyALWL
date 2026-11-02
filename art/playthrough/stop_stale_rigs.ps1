# Stops the playthrough session's stale picture-rig runs: every process that descends from a bash running art/playthrough/rig.sh, run_showroom.sh or run_world*.sh
# (the bash scripts, their xargs, and the Godot servers and clients they started). It keeps whatever descends from the processes named in -Keep (the live smoke test).
# Run it yourself in PowerShell:   powershell -File art\playthrough\stop_stale_rigs.ps1 -Keep 40160,6944
# Add -WhatIf to only list what would stop.
param([int[]]$Keep = @(), [switch]$WhatIf)
$all = Get-CimInstance Win32_Process
function Desc($id) { $kids = $all | Where-Object { $_.ParentProcessId -eq $id }; foreach ($k in $kids) { $k.ProcessId; Desc $k.ProcessId } }
$protect = @(); foreach ($r in $Keep) { $protect += $r; $protect += (Desc $r) }
# also protect the ancestors of every kept process, so the script never stops the shell that runs the live job
foreach ($r in $Keep) { $p = $all | Where-Object { $_.ProcessId -eq $r }; while ($p) { $protect += $p.ProcessId; $p = $all | Where-Object { $_.ProcessId -eq $p.ParentProcessId } } }
$roots = $all | Where-Object { $_.Name -in @('bash.exe', 'xargs.exe', 'timeout.exe') -and $_.CommandLine -match 'art/playthrough/(rig\.sh|run_showroom|run_world)' -and ($protect -notcontains $_.ProcessId) }
$kill = @(); foreach ($r in $roots) { $kill += $r.ProcessId; $kill += (Desc $r.ProcessId) }
$kill = $kill | Sort-Object -Unique | Where-Object { $protect -notcontains $_ }
"{0} processes: {1}" -f $kill.Count, (($all | Where-Object { $kill -contains $_.ProcessId } | Group-Object Name | ForEach-Object { $_.Name + "=" + $_.Count }) -join ", ")
if (-not $WhatIf) { foreach ($p in $kill) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue }; "stopped" }
