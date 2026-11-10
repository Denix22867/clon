<#
    build.ps1 — сборка guard.py в один файл guard.exe (Windows).
    Запускать в PowerShell НА WINDOWS (там, где установлен Python 3).

    Что делает:
      1) ставит pyinstaller (если нет);
      2) собирает guard.exe в папку dist\ одним файлом;
      3) exe при запуске сам запрашивает права администратора (манифест UAC).

    Использование:
      .\build.ps1                 # обычная сборка (с консолью для логов)
      .\build.ps1 -NoConsole      # без консольного окна (тихий фон)
      .\build.ps1 -Icon guard.ico # со своей иконкой

    Результат: dist\guard.exe
#>

param(
    [switch]$NoConsole,
    [string]$Icon
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

# 1) Python?
$py = (Get-Command python -ErrorAction SilentlyContinue)
if (-not $py) { throw "Не найден python в PATH. Установи Python 3 с python.org." }

# 2) PyInstaller?
python -c "import PyInstaller" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Ставлю PyInstaller..."
    python -m pip install --upgrade pip
    python -m pip install pyinstaller
}

# 3) сборка
$opts = @(
    "--onefile",            # один exe
    "--name", "guard",
    "--uac-admin",          # запрашивать админа при запуске
    "--clean", "--noconfirm"
)
if ($NoConsole) { $opts += "--noconsole" }      # без чёрного окна
if ($Icon)      { $opts += @("--icon", $Icon) }

Write-Host "Собираю guard.exe ..."
python -m PyInstaller @opts "guard.py"

$out = Join-Path $here "dist\guard.exe"
if (Test-Path $out) {
    Write-Host "`nГотово: $out"
    Write-Host "Запуск: правый клик -> Запуск от имени администратора (или просто двойной клик — попросит UAC)."
    Write-Host "ВНИМАНИЕ: антивирус может ругаться на свежий неподписанный exe (он правит реестр, ставит хуки, убивает процессы)."
    Write-Host "Это ложное срабатывание эвристики. Добавь исключение Defender на папку guard или подпиши exe своим сертификатом."
} else {
    throw "Сборка не создала dist\guard.exe — смотри вывод выше."
}
