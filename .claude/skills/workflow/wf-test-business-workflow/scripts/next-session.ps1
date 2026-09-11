# REQ-ID: REQ-QA-WF-BWTEST-001
# Windows spawner — mo Claude Code tab moi qua VS Code command palette.
# Khong mo terminal moi. Dung SendKeys + Win32 API.
# Exit 0 = spawn OK hoac STOP. Exit 1 = fail → FALLBACK MODE.
param(
    [switch]$DryRun,
    [string]$RunsDir = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = (Resolve-Path "$ScriptDir\..\..\..\..\..").Path

if (-not $RunsDir) {
    $RunsDir = Join-Path $RootDir ".mc-data\work\wf-test-business-workflow\_runs"
}

$StopPath     = Join-Path $RunsDir "STOP"
$ProgressPath = Join-Path $RunsDir "progress.json"
$PromptPath   = Join-Path $RunsDir "prompt-template.md"
$MirrorPath   = Join-Path $RunsDir ".machine-mirror.json"
$LogPath      = Join-Path $RunsDir "next-session.log"

function Write-Log($msg) {
    $ts = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    "$ts $msg" | Tee-Object -FilePath $LogPath -Append | Write-Host
}

# STOP check
if (Test-Path $StopPath) {
    Write-Log "STOP file detected. No spawn."
    exit 0
}

# Pending check
if (Test-Path $ProgressPath) {
    $progress = Get-Content $ProgressPath -Raw | ConvertFrom-Json
    $pending = ($progress.workflows.PSObject.Properties.Value |
                Where-Object { $_.status -eq "pending" }).Count
    if ($pending -eq 0) {
        Write-Log "No pending workflows. Loop complete."
        exit 0
    }
    Write-Log "$pending pending workflows."
}

# Check prompt file
if (-not (Test-Path $PromptPath)) {
    Write-Log "ERROR: prompt-template.md not found: $PromptPath"
    exit 1
}

# Load vscode_app from mirror (default: Code)
$vsCodeApp = "Code"
if (Test-Path $MirrorPath) {
    $mirror = Get-Content $MirrorPath -Raw | ConvertFrom-Json
    if ($mirror.vscode_app) { $vsCodeApp = $mirror.vscode_app }
}

# Copy prompt to clipboard (explicit UTF-8)
[System.IO.File]::ReadAllText($PromptPath, [System.Text.Encoding]::UTF8) | Set-Clipboard
Write-Log "Prompt copied to clipboard."

if ($DryRun) {
    Write-Log "[DRY-RUN] Would activate VS Code ($vsCodeApp) and open new Claude Code tab."
    exit 0
}

# Win32: bring VS Code window to foreground
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Helpers {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

# Tim VS Code process (thu tat ca variant pho bien)
$candidates = @($vsCodeApp, "Code", "code", "Antigravity", "antigravity", "Cursor", "Windsurf", "Code - Insiders")

# Pass 1: tim process co visible window
$vsProc = $null
foreach ($app in $candidates) {
    $vsProc = Get-Process -Name $app -ErrorAction SilentlyContinue |
              Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
              Select-Object -First 1
    if ($vsProc) { break }
}

# Pass 2: fallback — lay process bat ky (ke ca MainWindowHandle=0)
if (-not $vsProc) {
    Write-Log "Pass 1: no visible window found. Trying fallback (any process)..."
    foreach ($app in $candidates) {
        $vsProc = Get-Process -Name $app -ErrorAction SilentlyContinue |
                  Select-Object -First 1
        if ($vsProc) {
            Write-Log "Found $($vsProc.Name) process (HWND=$($vsProc.MainWindowHandle)). Attempting restore..."
            break
        }
    }
}

if (-not $vsProc) {
    Write-Log "ERROR: VS Code not running or no visible window. exit 1 -> FALLBACK"
    exit 1
}

# Kich hoat cua so (chi khi handle khac 0)
if ($vsProc.MainWindowHandle -ne [IntPtr]::Zero) {
    Write-Log "Activating VS Code window ($($vsProc.Name))..."
    [Win32Helpers]::ShowWindow($vsProc.MainWindowHandle, 9) | Out-Null  # SW_RESTORE
    [Win32Helpers]::SetForegroundWindow($vsProc.MainWindowHandle) | Out-Null
} else {
    Write-Log "MainWindowHandle is zero - relying on code.exe --reuse-window"
    $codeExe = $null
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:ProgramFiles\Microsoft VS Code\Code.exe"
    )
    foreach ($p in $possiblePaths) {
        if (Test-Path $p) { $codeExe = $p; break }
    }
    if (-not $codeExe) {
        $codeExe = (Get-Command "code" -ErrorAction SilentlyContinue).Source
    }
    if ($codeExe) {
        Write-Log "Activating via: $codeExe"
        Start-Process -FilePath $codeExe -ArgumentList "--reuse-window" -WindowStyle Normal
        Start-Sleep -Milliseconds 1500
    }
}
Start-Sleep -Milliseconds 800

# Keyboard automation qua SendKeys
Add-Type -AssemblyName System.Windows.Forms

Write-Log "Opening command palette (Ctrl+Shift+P)..."
[System.Windows.Forms.SendKeys]::SendWait("^+p")
Start-Sleep -Milliseconds 800

# Go vao command mode (>) de tranh match files/symbols
Write-Log "Typing: Claude Code: New Tab"
[System.Windows.Forms.SendKeys]::SendWait("Claude Code: New Tab")
Start-Sleep -Milliseconds 600

# Chon command (Enter)
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Milliseconds 2500  # Doi tab moi init

# Paste prompt (Ctrl+V)
[System.Windows.Forms.SendKeys]::SendWait("^v")
Start-Sleep -Milliseconds 500

# Submit (Enter)
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

Write-Log "New Claude Code tab spawned. Prompt pasted. exit 0"
exit 0
