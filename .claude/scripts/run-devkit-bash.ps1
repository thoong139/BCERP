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

function Convert-ToGitBashPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if ($resolved -match "^([A-Za-z]):\\(.*)$") {
        $drive = $matches[1].ToLowerInvariant()
        $rest = $matches[2] -replace "\\", "/"
        return "/$drive/$rest"
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

# Phát hiện loại bash: WSL (System32/WindowsApps/wsl) vs Git Bash (thư mục cài Git).
# WSL dùng đường dẫn /mnt/<drive>/...; Git Bash dùng /<drive>/... — dùng sai loại
# đường dẫn sẽ trỏ tới thư mục không tồn tại.
$bashSource = $bash.Source
$isWslBash = $bashSource -match "System32|WindowsApps|\\wsl\\"

$quotedArgs = @()

if ($null -ne $ScriptArgs) {
    $quotedArgs = @($ScriptArgs) | ForEach-Object { Quote-ForBash -Value $_ }
}

if ($isWslBash) {
    $repoRootBash = Convert-ToWslPath -Path $repoRoot
    $scriptPathBash = Convert-ToWslPath -Path $scriptPath
    $command = "cd $(Quote-ForBash -Value $repoRootBash) && bash $(Quote-ForBash -Value $scriptPathBash)"
    if (@($quotedArgs).Count -gt 0) {
        $command += " " + ($quotedArgs -join " ")
    }
    & $bash.Source -lc $command
    exit $LASTEXITCODE
}
else {
    $repoRootBash = Convert-ToGitBashPath -Path $repoRoot
    $scriptPathBash = Convert-ToGitBashPath -Path $scriptPath
    $command = "cd $(Quote-ForBash -Value $repoRootBash) && bash $(Quote-ForBash -Value $scriptPathBash)"
    if (@($quotedArgs).Count -gt 0) {
        $command += " " + ($quotedArgs -join " ")
    }
    & $bash.Source -c $command
    exit $LASTEXITCODE
}
