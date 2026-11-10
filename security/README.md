# Защита Windows 10/11 от локеров и шифровальщиков

Набор защитных инструментов. Ничего не прячется, ничего не атакует —
только оборона твоего же ПК. Всё удаляется и откатывается.

## Состав

| Файл | Назначение |
|---|---|
| `guard.py` | Агент: автозагрузка, Defender CFA, canary-ловушки, защита SafeBoot, **защита WinRE** (бэкап + авто-восстановление и включение), **мониторинг теневых копий VSS**, снятие блокировки клавы/TaskMgr, паник-клавиша, админ-«часовой» против локеров |
| `AppLocker-DefaultDeny.xml` | Политика «разрешено запускать только из Windows/Program Files» — реальный барьер «не дать запуститься» |
| `apply-applocker.ps1` | Безопасное применение AppLocker (сначала аудит, потом блокировка) |
| `backup.ps1` | Версионный авто-бэкап важных папок (снимки по датам, не зеркало) |

## Порядок защиты (от сильного к вспомогательному)

### 1. Офлайн-бэкап — главное
Правило 3-2-1: 3 копии, 2 носителя, 1 офлайн/офсайт. Даже если зашифруют —
восстановишься. Никакой софт этого не заменит.

```powershell
# версионный бэкап (снимки по датам, не зеркало — старые копии переживут шифрование):
.\backup.ps1 -Target D:\Backups
.\backup.ps1 -Target D:\Backups -InstallTask   # ежедневно в 13:00
```
> Лучший носитель — съёмный диск, который **отключаешь** после бэкапа, или
> облако/NAS с версионностью. Постоянно подключённый диск шифровальщик заберёт вместе со всем.

### 2. AppLocker default-deny — «не дать запуститься»
Блокирует неизвестные `.exe`/скрипты из `Temp`, `Downloads`, `AppData`, USB
**до выполнения кода**, на уровне ОС. Это и есть надёжная профилактика.

```powershell
# PowerShell от администратора, из папки security:
.\apply-applocker.ps1 -Mode Audit      # 1) только журнал, ничего не блокирует
# ... поработай день, позапускай свои программы ...
.\apply-applocker.ps1 -Report          # 2) что БЫЛО БЫ заблокировано
# ... при необходимости добавь исключения в XML ...
.\apply-applocker.ps1 -Mode Enforce    # 3) включить блокировку
.\apply-applocker.ps1 -Clear           # откат (сброс политики)
```

> Если нужная программа живёт вне Program Files (портативный софт) — добавь для
> неё отдельное `FilePathRule`/`FilePublisherCondition` в XML, прежде чем включать Enforce.

### 3. Defender ASR + Controlled Folder Access — поведенческий блок
```powershell
Set-MpPreference -EnableControlledFolderAccess Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids c1db55ab-c21a-4637-bb3f-a12568109d35 `
                 -AttackSurfaceReductionRules_Actions Enabled
```

### 4. guard.py — усиление и быстрое лечение
```powershell
python guard.py                   # ПКМ → запуск от администратора
python guard.py --install-system  # доп. SYSTEM-задача на загрузку
python guard.py --uninstall       # снять автозапуск
```
Реакция на шифрование настраивается в начале файла: `ON_TRIP = "lock" | "shutdown" | "alert"`.

При нейтрализации локера guard показывает **уведомление Windows** и открывает
**красивый HTML-отчёт об инциденте** (папка `incidents/`) с деталями: какой процесс
убит, какие копии удалены, какая персистентность вычищена.

## Пример: разбор HollyChecker.exe (WinLocker)

Образец проанализирован в песочнице Triage (score 7/10). **Это скрин-локер, а не
настоящий шифровальщик** — файловая активность показала, что он сбросил только свою
PyInstaller-начинку в `Temp\_MEI...\`, зашифрованных файлов и записок-вымогателей нет.
Надпись «Ваши файлы зашифрованы» — запугивание.

Реальное поведение и чем закрывается:

| Индикатор | Защита |
|---|---|
| Запуск из `AppData\Local\Temp\HollyChecker.exe` | **AppLocker** блокирует (Temp не разрешён) |
| Копия в `AppData\Roaming\WindowsUpdateService\` | guard: kill по имени + удаление копии |
| `Run` + `RunOnce` = `WinLockerService` | guard: чистка Run/RunOnce (HKCU+HKLM) |
| Файл в Startup | guard: чистка Startup |
| Задача schtasks `WinLockerService` (ONLOGON) | guard: удаление задачи |
| Полноэкранное окно + `SetWindowsHookEx` | guard: «часовой» убивает процесс → хуки спадают |
| `DisableTaskMgr`, `BlockInput` | guard: сброс политик + BlockInput(False) |

IOC (для блок-листов/поиска):
- SHA-256: `548d7d990942c8c0b48432b59d7e8963b927d080a5ea4950146fa5c54ff6e066`
- Пути: `…\AppData\Roaming\WindowsUpdateService\HollyChecker.exe`
- Реестр: `…\CurrentVersion\Run(Once)\WinLockerService`
- Задача: `WinLockerService`
- Telegram в тексте: `@WinLockerHollyChecker`

> Снять такой локер вручную: безопасный режим → удалить копии и записи автозапуска выше,
> либо дать поработать guard от администратора. Настоящего шифрования тут нет.

## Честные границы
- `guard.py` — агент пользовательского режима: он **не** перехватывает запись в файлы
  драйвером и **не** даёт абсолютной гарантии. Надёжную блокировку дают слои 2–3 (ядро).
- «Часовой» убивает локер уже после запуска (гонка) — это лечение, не профилактика.
- Главный щит — пункт 1 (бэкап) и пункт 2 (AppLocker).

## Удаление всего
```powershell
python guard.py --uninstall
.\apply-applocker.ps1 -Clear
Set-MpPreference -EnableControlledFolderAccess Disabled   # если хочешь выключить CFA
```
