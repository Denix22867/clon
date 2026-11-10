<#
    backup.ps1 — версионный авто-бэкап важных папок (защита от шифровальщиков).
    Запускать в PowerShell (для задачи по расписанию — от администратора).

    Ключевая идея против ransomware: бэкап должен быть ВЕРСИОННЫМ и по возможности
    ОФЛАЙН. Поэтому здесь НЕ зеркало (/MIR), а снимки по датам — если источник
    зашифруют, старые снимки останутся целыми. Плюс скрипт держит последние N снимков.

    Примеры:
      .\backup.ps1 -Target D:\Backups
      .\backup.ps1 -Target \\nas\backup -Keep 10
      .\backup.ps1 -Target E:\Backups -Sources "C:\Users\me\Documents","C:\Work"
      .\backup.ps1 -Target D:\Backups -InstallTask   # ежедневная задача в 13:00

    ВАЖНО: лучший носитель — съёмный диск, который ты ОТКЛЮЧАЕШЬ после бэкапа,
    или облако/NAS с версионностью и отдельными учётными данными. Диск, постоянно
    подключённый и доступный на запись, шифровальщик зашифрует вместе с остальным.
#>

param(
    [Parameter(Mandatory = $true)] [string]$Target,
    [string[]]$Sources,
    [int]$Keep = 7,
    [switch]$InstallTask
)

$ErrorActionPreference = "Stop"

if (-not $Sources -or $Sources.Count -eq 0) {
    $Sources = @(
        [Environment]::GetFolderPath('MyDocuments'),
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('MyPictures')
    ) | Where-Object { Test-Path $_ }
}

if ($InstallTask) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $srcArg = ($Sources | ForEach-Object { '"{0}"' -f $_ }) -join ','
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Target `"$Target`" -Sources $srcArg -Keep $Keep"
    $trigger = New-ScheduledTaskTrigger -Daily -At 1:00PM
    Register-ScheduledTask -TaskName "GuardBackup" -Action $action -Trigger $trigger `
        -RunLevel Highest -Force | Out-Null
    Write-Host "Задача GuardBackup создана (ежедневно в 13:00). Цель: $Target"
    return
}

if (-not (Test-Path $Target)) {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
}

$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$dest = Join-Path $Target $stamp
Write-Host "Снимок: $dest"

foreach ($src in $Sources) {
    if (-not (Test-Path $src)) { continue }
    $name = Split-Path $src -Leaf
    $out = Join-Path $dest $name
    Write-Host "  -> $src"
    # /E все подпапки, /COPY:DAT, /R:1 /W:1 быстрые повторы, /XJ без junction-петель
    robocopy $src $out /E /COPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NP | Out-Null
}

# чистим старые снимки, оставляя последние $Keep
$snaps = Get-ChildItem $Target -Directory |
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}$' } |
    Sort-Object Name -Descending
if ($snaps.Count -gt $Keep) {
    $snaps | Select-Object -Skip $Keep | ForEach-Object {
        Write-Host "Удаляю старый снимок: $($_.Name)"
        Remove-Item $_.FullName -Recurse -Force
    }
}

Write-Host "Готово. Снимков хранится: $([Math]::Min($snaps.Count, $Keep))"
Write-Host "НАПОМИНАНИЕ: отключи съёмный диск после бэкапа — так его не зашифруют."
