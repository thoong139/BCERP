param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Script,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Convert-ToWslPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if ($resolved -match "^([A-Za-z]):\\(.*)$") {
        $drive = $matches[1].ToLowerInvariant()
        $rest = $matches[2] -replace "\\", "/"
        return "/mnt/$drive/$rest"
    }

    throw "Unsupported path format: $resolved"
}

function Quote-ForBash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $escaped = $Value -replace "'", "'""'""'"
    return "'" + $escaped + "'"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$scriptCandidate = if ([System.IO.Path]::IsPathRooted($Script)) {
    $Script
} else {
    Join-Path $repoRoot $Script
}

$scriptPath = (Resolve-Path -LiteralPath $scriptCandidate).Path
$comparison = [System.StringComparison]::OrdinalIgnoreCase

if (-not $scriptPath.StartsWith($repoRoot, $comparison)) {
    throw "Script must be inside repo root: $repoRoot"
}

if (-not $scriptPath.ToLowerInvariant().EndsWith(".sh")) {
    throw "Wrapper only supports .sh scripts: $scriptPath"
}

$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash) {
    throw "bash.exe was not found. Install WSL or Git Bash before using this wrapper."
}

$repoRootWsl = Convert-ToWslPath -Path $repoRoot
$scriptPathWsl = Convert-ToWslPath -Path $scriptPath
$quotedArgs = @()

if ($null -ne $ScriptArgs) {
    $quotedArgs = @($ScriptArgs) | ForEach-Object { Quote-ForBash -Value $_ }
}

$command = "cd $(Quote-ForBash -Value $repoRootWsl) && bash $(Quote-ForBash -Value $scriptPathWsl)"
if (@($quotedArgs).Count -gt 0) {
    $command += " " + ($quotedArgs -join " ")
}

& $bash.Source -lc $command
exit $LASTEXITCODE
