<#
    build.ps1 - build guard.py into a single guard.exe (Windows).
    Run in PowerShell ON WINDOWS (where Python 3 is installed).

    Steps:
      1) installs pyinstaller if missing;
      2) builds dist\guard.exe as one file;
      3) the exe requests admin rights on launch (UAC manifest).

    Usage:
      .\build.ps1                 # normal build (with console for logs)
      .\build.ps1 -NoConsole      # no console window (silent background)
      .\build.ps1 -Icon guard.ico # custom icon

    Output: dist\guard.exe
#>

param(
    [switch]$NoConsole,
    [string]$Icon
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

# 1) Python present?
$py = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $py) { throw "python not found in PATH. Install Python 3 from python.org." }

# 2) PyInstaller present?
python -c "import PyInstaller" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing PyInstaller..."
    python -m pip install --upgrade pip
    python -m pip install pyinstaller
}

# 3) build
$opts = @(
    "--onefile",
    "--name", "guard",
    "--uac-admin",
    "--clean", "--noconfirm"
)
if ($NoConsole) { $opts += "--noconsole" }
if ($Icon)      { $opts += @("--icon", $Icon) }

Write-Host "Building guard.exe ..."
python -m PyInstaller @opts "guard.py"

$out = Join-Path $here "dist\guard.exe"
if (Test-Path $out) {
    Write-Host ""
    Write-Host "Done: $out"
    Write-Host "Run: right-click -> Run as administrator (or double-click, it will ask UAC)."
    Write-Host "NOTE: antivirus may flag a fresh unsigned exe (it edits registry, sets hooks, kills processes)."
    Write-Host "That is a heuristic false positive. Add a Defender exclusion for the guard folder, or sign the exe."
} else {
    throw "Build did not produce dist\guard.exe - see output above."
}
