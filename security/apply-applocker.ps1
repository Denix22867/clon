<#
    apply-applocker.ps1 — безопасное применение AppLocker default-deny.
    Запускать в PowerShell ОТ АДМИНИСТРАТОРА.

    Порядок (важно, чтобы не заблокировать себе систему):
      1) .\apply-applocker.ps1 -Mode Audit     # только журналирование, ничего не блокирует
      2) поработай день, запусти свои программы
      3) .\apply-applocker.ps1 -Report         # посмотреть, что БЫЛО БЫ заблокировано
      4) добавь исключения, если нужно (см. README)
      5) .\apply-applocker.ps1 -Mode Enforce   # включить реальную блокировку

    Откат: .\apply-applocker.ps1 -Clear
#>

param(
    [ValidateSet("Audit", "Enforce")] [string]$Mode,
    [switch]$Report,
    [switch]$Clear
)

$ErrorActionPreference = "Stop"
$PolicyPath = Join-Path $PSScriptRoot "AppLocker-DefaultDeny.xml"

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        throw "Нужен запуск от администратора."
    }
}

function Ensure-AppIDSvc {
    # Служба Application Identity обязательна для AppLocker
    $svc = Get-Service AppIDSvc -ErrorAction SilentlyContinue
    if ($svc.StartType -ne 'Automatic') {
        Write-Host "Ставлю службу AppIDSvc в автозапуск..."
        Set-Service AppIDSvc -StartupType Automatic
    }
    if ($svc.Status -ne 'Running') {
        Start-Service AppIDSvc
    }
}

Assert-Admin

if ($Clear) {
    Write-Host "Очищаю политику AppLocker (пустая политика = всё разрешено)..."
    $empty = "<AppLockerPolicy Version=`"1`"></AppLockerPolicy>"
    $tmp = Join-Path $env:TEMP "applocker_empty.xml"
    $empty | Set-Content -Path $tmp -Encoding UTF8
    Set-AppLockerPolicy -XmlPolicy $tmp
    Remove-Item $tmp -Force
    Write-Host "Готово: AppLocker сброшен."
    return
}

if ($Report) {
    Write-Host "События AppLocker (что было бы заблокировано), последние 50:`n"
    Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" -MaxEvents 50 -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -in 8003, 8004 } |
        Select-Object TimeCreated, Id, Message | Format-List
    Write-Host "`nId 8003 = было бы заблокировано (Audit); 8004 = заблокировано (Enforce)."
    return
}

if (-not $Mode) {
    Write-Host "Укажи -Mode Audit | -Mode Enforce, либо -Report / -Clear."
    return
}

if (-not (Test-Path $PolicyPath)) { throw "Не найден $PolicyPath" }

Ensure-AppIDSvc

# подставляем режим в XML
[xml]$xml = Get-Content $PolicyPath
$enf = if ($Mode -eq "Enforce") { "Enabled" } else { "AuditOnly" }
foreach ($rc in $xml.AppLockerPolicy.RuleCollection) { $rc.EnforcementMode = $enf }

$tmp = Join-Path $env:TEMP "applocker_apply.xml"
$xml.Save($tmp)
Set-AppLockerPolicy -XmlPolicy $tmp
Remove-Item $tmp -Force

Write-Host "Политика применена в режиме: $Mode ($enf)."
if ($Mode -eq "Audit") {
    Write-Host "Ничего не блокируется — только пишется в журнал. Потом: -Report, затем -Mode Enforce."
} else {
    Write-Host "ВКЛЮЧЕНА блокировка. Запуск из Temp/Downloads/AppData/USB теперь запрещён (кроме админов)."
}
