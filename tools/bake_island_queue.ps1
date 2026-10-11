param(
    [string]$GodotPath = "godot",
    [int]$Workers = 0,
    [string]$QueuePath = "$PSScriptRoot/island_queue.txt",
    [string]$Output = "res://worlds/base_world/regions"
)

$ErrorActionPreference = "Stop"
$projectPath = Split-Path -Parent $PSScriptRoot

foreach ($line in Get-Content -LiteralPath $QueuePath) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
        continue
    }

    $parts = $trimmed.Split(",")
    if ($parts.Count -ne 2) {
        throw "Invalid queue entry: $trimmed"
    }

    $tileX = [int]$parts[0].Trim()
    $tileZ = [int]$parts[1].Trim()
    $arguments = @(
        "--headless",
        "--path", $projectPath,
        "--",
        "--role=builder",
        "--island-x=$tileX",
        "--island-z=$tileZ",
        "--output=$Output",
        "--quit-on-finish=true"
    )

    if ($Workers -gt 0) {
        $arguments += "--workers=$Workers"
    }

    Write-Host "Baking island tile ($tileX, $tileZ)..."
    & $GodotPath @arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Island tile ($tileX, $tileZ) failed with exit code $LASTEXITCODE."
    }
}

Write-Host "Island queue complete."
