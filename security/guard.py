"""
guard.py — единый защитный агент для Windows 10/11.

Запускаешь один раз (лучше ОТ АДМИНИСТРАТОРА) — он делает всё:
  * ставит себя в автозагрузку (прозрачно: ярлык в папке Startup);
  * включает защиту Defender от шифрования (Controlled Folder Access) — нужен админ;
  * раскладывает canary-ловушки и при массовом шифровании блокирует/выключает ПК;
  * бережёт ключи безопасного режима (SafeBoot) и восстанавливает их;
  * защищает среду восстановления WinRE: бэкап ReAgent.xml/Winre.wim, и если её
    отключили (reagentc /disable) или стёрли — восстанавливает и включает обратно;
  * следит за теневыми копиями (VSS): поднимает отключённую службу и бьёт тревогу,
    если все теневые копии вдруг удалили (типичный шаг перед шифрованием);
  * держит DisableTaskMgr/DisableRegistryTools в 0 и снимает BlockInput (анти-локер клавы);
  * паник-клавиша Ctrl+Alt+K закрывает активное полноэкранное окно-пугалку;
  * АДМИНСКИЙ "часовой": ловит полноэкранное безрамочное topmost-окно локера,
    убивает его процесс (с ним спадают хуки/BlockInput) и чистит персистентность
    (Run в HKCU/HKLM, файлы Startup, задачи schtasks), ссылающуюся на тот же файл.

Команды:
  python guard.py                 # запустить защиту (+ прописать автозапуск)
  python guard.py --no-install    # запустить без добавления в автозагрузку
  python guard.py --uninstall     # убрать из автозагрузки и выйти
  python guard.py --install-system  # доп. SYSTEM-задача на загрузку (нужен админ)

Честные границы:
  - гарантированное "не дать запуститься" = AppLocker/WDAC (default-deny) + Defender ASR;
  - canary — раннее оповещение, не абсолютная блокировка;
  - "часовой" — лечение силой (гонка), а не абсолютная блокировка;
  - главный щит от шифровальщиков — офлайн-бэкапы (правило 3-2-1).
"""

import ctypes
import ctypes.wintypes as wt
import hashlib
import os
import re
import shutil
import subprocess
import sys
import time
import winreg

user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

BASE = os.path.dirname(os.path.abspath(__file__))
LOG_PATH = os.path.join(BASE, "guard.log")
SAFEBOOT_BACKUP = os.path.join(BASE, "safeboot_backup.reg")
WINDIR = os.environ.get("WINDIR", r"C:\Windows")
WINRE_DIR = os.path.join(WINDIR, "System32", "Recovery")
WINRE_BACKUP = os.path.join(BASE, "winre_backup")
WINRE_INTERVAL = 5.0  # сек между проверками WinRE (reagentc медленный)
VSS_INTERVAL = 5.0    # сек между проверками теневых копий

# реакция при срабатывании ловушки: "lock" | "shutdown" | "alert"
ON_TRIP = "lock"
SCAN_INTERVAL = 0.5

CANARY_NAME = "!!!_НЕ_УДАЛЯТЬ_guard_canary.txt"
CANARY_CONTENT = (
    "Файл-ловушка защитного агента guard. Не трогайте. "
    "Если он изменился сам — возможно, работает шифровальщик.\n"
).encode("utf-8")

SAFEBOOT_KEY = r"HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot"
POLICY_PATH = r"Software\Microsoft\Windows\CurrentVersion\Policies\System"
POLICY_NAMES = ("DisableTaskMgr", "DisableRegistryTools",
                "DisableLockWorkstation", "DisableChangePassword")
RUN_PATHS = [
    (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Run"),
    (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Run"),
    (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\RunOnce"),
    (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\RunOnce"),
]
STARTUP_DIR = os.path.join(os.environ.get("APPDATA", ""),
                           r"Microsoft\Windows\Start Menu\Programs\Startup")
WHITELIST_CLASSES = {"Shell_TrayWnd", "Progman", "WorkerW",
                     "Windows.UI.Core.CoreWindow"}


def log(m: str) -> None:
    line = f"{time.strftime('%Y-%m-%d %H:%M:%S')}  {m}"
    print(line)
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def is_admin() -> bool:
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


def run_ps(cmd: str):
    return subprocess.run(["powershell", "-NoProfile", "-Command", cmd],
                          capture_output=True, text=True)


# =======================================================================
#  АВТОЗАГРУЗКА
# =======================================================================
def _python_exe() -> str:
    pyw = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")
    return pyw if os.path.exists(pyw) else sys.executable


def startup_shortcut() -> str:
    return os.path.join(STARTUP_DIR, "guard.lnk")


def install_autostart() -> None:
    script = os.path.abspath(__file__)
    lnk = startup_shortcut()
    ps = (
        f"$s=(New-Object -ComObject WScript.Shell).CreateShortcut('{lnk}');"
        f"$s.TargetPath='{_python_exe()}';"
        f"$s.Arguments='\"{script}\" --no-install';"
        f"$s.WorkingDirectory='{os.path.dirname(script)}';"
        f"$s.Save()"
    )
    run_ps(ps)
    log("Автозагрузка настроена: " + lnk)


def uninstall_autostart() -> None:
    lnk = startup_shortcut()
    if os.path.exists(lnk):
        os.remove(lnk)
        log("Убрано из автозагрузки: " + lnk)
    else:
        log("Ярлыка автозагрузки нет.")
    subprocess.run(["schtasks", "/Delete", "/TN", "GuardSentinel", "/F"],
                   capture_output=True, creationflags=0x08000000)


def install_system_task() -> None:
    if not is_admin():
        log("Для SYSTEM-задачи нужен запуск от администратора.")
        return
    script = os.path.abspath(__file__)
    subprocess.run(
        ["schtasks", "/Create", "/TN", "GuardSentinel", "/SC", "ONSTART",
         "/RU", "SYSTEM", "/RL", "HIGHEST",
         "/TR", f'"{_python_exe()}" "{script}" --no-install', "/F"],
        capture_output=True, creationflags=0x08000000)
    log("Установлена SYSTEM-задача GuardSentinel (старт при загрузке).")


# =======================================================================
#  ЗАЩИТА ОТ ШИФРОВАНИЯ: Defender CFA + canary
# =======================================================================
def enable_defender_cfa() -> None:
    if not is_admin():
        log("Defender CFA не включён: нужен запуск от администратора.")
        return
    r = run_ps("Set-MpPreference -EnableControlledFolderAccess Enabled")
    if r.returncode == 0:
        log("Controlled Folder Access ВКЛЮЧЁН (защита папок от шифрования).")
    else:
        log("Не удалось включить CFA: " + (r.stderr or r.stdout).strip())


def canary_dirs() -> list:
    home = os.path.expanduser("~")
    cands = [os.path.join(home, x) for x in ("Documents", "Desktop", "Pictures")]
    cands.append(home)
    return [d for d in cands if os.path.isdir(d)]


def plant_canaries() -> dict:
    expected, h = {}, hashlib.sha256(CANARY_CONTENT).hexdigest()
    for d in canary_dirs():
        p = os.path.join(d, CANARY_NAME)
        try:
            with open(p, "wb") as f:
                f.write(CANARY_CONTENT)
            expected[p] = h
        except OSError as e:
            log(f"Ловушка не поставлена в {d}: {e}")
    log(f"Ловушек установлено: {len(expected)}")
    return expected


def canary_tripped(expected: dict) -> list:
    tripped = []
    for p, h in expected.items():
        try:
            with open(p, "rb") as f:
                if hashlib.sha256(f.read()).hexdigest() != h:
                    tripped.append(p + " (изменён)")
        except FileNotFoundError:
            tripped.append(p + " (удалён)")
        except OSError:
            tripped.append(p + " (нет доступа — возможно, зашифрован)")
    return tripped


def react(reason: str) -> None:
    log("!!! ТРЕВОГА — возможен шифровальщик: " + reason)
    if ON_TRIP == "lock":
        log("Блокирую рабочую станцию.")
        user32.LockWorkStation()
    elif ON_TRIP == "shutdown":
        log("Аварийное выключение.")
        subprocess.run(["shutdown", "/s", "/t", "0", "/f"])
    else:
        log("Режим alert: проверь систему немедленно.")


# =======================================================================
#  ЗАЩИТА SafeBoot
# =======================================================================
def backup_safeboot() -> None:
    if is_admin():
        r = subprocess.run(["reg", "export", SAFEBOOT_KEY, SAFEBOOT_BACKUP, "/y"],
                           capture_output=True, text=True)
        if r.returncode == 0:
            log("Бэкап SafeBoot сохранён.")


def safeboot_ok() -> bool:
    for sub in ("Minimal", "Network"):
        r = subprocess.run(["reg", "query", SAFEBOOT_KEY + "\\" + sub],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return False
    return True


def restore_safeboot() -> None:
    if is_admin() and os.path.exists(SAFEBOOT_BACKUP):
        r = subprocess.run(["reg", "import", SAFEBOOT_BACKUP],
                           capture_output=True, text=True)
        if r.returncode == 0:
            log("SafeBoot восстановлен из бэкапа.")


# =======================================================================
#  ЗАЩИТА СРЕДЫ ВОССТАНОВЛЕНИЯ WinRE
# =======================================================================
def winre_status():
    """Вернёт ('enabled'|'disabled'|'unknown', текст). Язык-агностично."""
    r = subprocess.run(["reagentc", "/info"], capture_output=True, text=True,
                       creationflags=0x08000000)
    out = ((r.stdout or "") + (r.stderr or "")).lower()
    if "disabled" in out or "отключен" in out:
        return "disabled", out
    if "enabled" in out or "включен" in out:
        return "enabled", out
    return "unknown", out


def winre_backup() -> None:
    """Сохраняет ReAgent.xml и Winre.wim, пока они на месте (нужен админ)."""
    if not is_admin():
        return
    try:
        os.makedirs(WINRE_BACKUP, exist_ok=True)
        saved = []
        for fn in ("ReAgent.xml", "Winre.wim"):
            src = os.path.join(WINRE_DIR, fn)
            if os.path.exists(src):
                shutil.copy2(src, os.path.join(WINRE_BACKUP, fn))
                saved.append(fn)
        if saved:
            log("Бэкап WinRE обновлён: " + ", ".join(saved))
        else:
            log("WinRE: файлы ReAgent.xml/Winre.wim не найдены в System32\\Recovery "
                "(возможно, образ на отдельном разделе восстановления).")
    except OSError as e:
        log("Бэкап WinRE не удался: %s" % e)


def winre_protect() -> None:
    """Если WinRE отключили/стёрли — восстановить файлы и включить обратно."""
    if not is_admin():
        return
    status, _ = winre_status()
    if status != "disabled":
        return
    log("ВНИМАНИЕ: WinRE ОТКЛЮЧЁН — восстанавливаю.")
    # вернуть стёртые файлы из бэкапа
    try:
        os.makedirs(WINRE_DIR, exist_ok=True)
        for fn in ("ReAgent.xml", "Winre.wim"):
            bak = os.path.join(WINRE_BACKUP, fn)
            dst = os.path.join(WINRE_DIR, fn)
            if os.path.exists(bak) and not os.path.exists(dst):
                shutil.copy2(bak, dst)
                log("WinRE: восстановлен из бэкапа " + fn)
    except OSError as e:
        log("WinRE: восстановить файлы не вышло: %s" % e)
    # включить снова
    r = subprocess.run(["reagentc", "/enable"], capture_output=True, text=True,
                       creationflags=0x08000000)
    if r.returncode == 0:
        log("WinRE снова включён (reagentc /enable).")
    else:
        log("WinRE: автоматически включить не удалось: "
            + (r.stdout or r.stderr).strip()
            + "  Если образ стёрт — восстанови через установочный носитель "
              "(reagentc /setreimage /path <WinRE.wim>).")


# =======================================================================
#  МОНИТОРИНГ ТЕНЕВЫХ КОПИЙ (VSS)
# =======================================================================
# Шифровальщики почти всегда удаляют теневые копии перед шифрованием
# (vssadmin delete shadows /all, wmic shadowcopy delete, wbadmin delete catalog,
#  отключение службы VSS), чтобы отрезать откат. Резкое исчезновение всех
# теневых копий — сильный ранний признак атаки.
_vss_seen = 0  # максимум теневых копий, что мы видели (была защита)


def vss_count() -> int:
    """Число теневых копий (по GUID). Нужен админ; иначе -1."""
    r = subprocess.run(["vssadmin", "list", "shadows"],
                       capture_output=True, text=True, creationflags=0x08000000)
    out = (r.stdout or "") + (r.stderr or "")
    if "administrator" in out.lower() or "администратора" in out.lower():
        return -1
    return len(re.findall(r"\{[0-9A-Fa-f-]{36}\}", out))


def ensure_vss_service() -> None:
    """Если службу VSS отключили — вернуть в ручной запуск и поднять."""
    if not is_admin():
        return
    q = subprocess.run(["sc", "qc", "VSS"], capture_output=True, text=True,
                       creationflags=0x08000000)
    if "DISABLED" in (q.stdout or "").upper():
        subprocess.run(["sc", "config", "VSS", "start=", "demand"],
                       capture_output=True, creationflags=0x08000000)
        subprocess.run(["sc", "start", "VSS"],
                       capture_output=True, creationflags=0x08000000)
        log("Служба VSS была отключена — возвращена в ручной запуск.")


def vss_protect() -> None:
    """Следит за резким удалением всех теневых копий."""
    global _vss_seen
    if not is_admin():
        return
    ensure_vss_service()
    cnt = vss_count()
    if cnt < 0:
        return
    if cnt > _vss_seen:
        _vss_seen = cnt
    if _vss_seen > 0 and cnt == 0:
        react("удалены ВСЕ теневые копии (VSS) — типичный шаг перед шифрованием")
        _vss_seen = 0  # чтобы не зациклить тревогу


# =======================================================================
#  АНТИ-БЛОКИРОВКА КЛАВИАТУРЫ / TASKMGR
# =======================================================================
def fix_keyboard_and_taskmgr() -> bool:
    """Снимает BlockInput и чинит ключи политик. True если была подделка."""
    tampered = False
    try:
        user32.BlockInput(False)
    except Exception:
        pass
    try:
        k = winreg.CreateKeyEx(winreg.HKEY_CURRENT_USER, POLICY_PATH, 0,
                               winreg.KEY_READ | winreg.KEY_SET_VALUE)
        for name in POLICY_NAMES:
            try:
                val, _ = winreg.QueryValueEx(k, name)
            except FileNotFoundError:
                val = 0
            if val == 1:
                tampered = True
                winreg.SetValueEx(k, name, 0, winreg.REG_DWORD, 0)
                log(f"Снята блокировка политики: {name}")
        winreg.CloseKey(k)
    except OSError:
        pass
    return tampered


# =======================================================================
#  ДЕТЕКТОР + УБИЙЦА ЛОКЕРОВ (часовой)
# =======================================================================
def _image_path(pid: int) -> str:
    h = kernel32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not h:
        return ""
    try:
        buf = ctypes.create_unicode_buffer(32768)
        size = wt.DWORD(32768)
        if kernel32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)):
            return buf.value
        return ""
    finally:
        kernel32.CloseHandle(h)


def _class_name(hwnd) -> str:
    b = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(hwnd, b, 256)
    return b.value


def _title(hwnd) -> str:
    b = ctypes.create_unicode_buffer(512)
    user32.GetWindowTextW(hwnd, b, 512)
    return b.value


def find_locker_windows() -> list:
    """[(hwnd, pid, image)] для полноэкранных безрамочных topmost-окон."""
    found = []
    EnumProc = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)

    def cb(hwnd, _):
        if not user32.IsWindowVisible(hwnd) or _class_name(hwnd) in WHITELIST_CLASSES:
            return True
        rect = wt.RECT()
        if not user32.GetWindowRect(hwnd, ctypes.byref(rect)):
            return True
        sw, sh = user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)
        covers = (rect.right - rect.left) >= sw and (rect.bottom - rect.top) >= sh
        if not covers:
            return True
        ex = user32.GetWindowLongW(hwnd, -20)
        st = user32.GetWindowLongW(hwnd, -16)
        topmost = bool(ex & 0x00000008)          # WS_EX_TOPMOST
        borderless = not (st & 0x00C00000)        # нет WS_CAPTION
        if topmost and borderless:
            pid = wt.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            found.append((hwnd, pid.value, _image_path(pid.value)))
        return True

    user32.EnumWindows(EnumProc(cb), 0)
    return found


def kill_tree(pid: int) -> None:
    subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)],
                   capture_output=True, creationflags=0x08000000)


_PATH_RE = re.compile(r'([A-Za-z]:\\[^"\r\n]+?\.exe)', re.IGNORECASE)


def purge_persistence(image_path: str) -> None:
    """Чистит ВСЮ персистентность по имени файла локера: Run/RunOnce (HKCU+HKLM),
    Startup, задачи schtasks — и находит/удаляет ВТОРУЮ копию (напр. в Roaming),
    затем убивает все запущенные копии по имени процесса."""
    if not image_path:
        return
    base = os.path.basename(os.path.normcase(image_path)).lower()
    if not base.endswith(".exe"):
        base += ""  # на всякий случай
    copy_paths = {os.path.normcase(image_path)}  # все известные пути копий

    # ключи Run / RunOnce — матчим по ИМЕНИ файла, а не по конкретному пути,
    # чтобы поймать и Temp-, и Roaming-копию
    for root, path in RUN_PATHS:
        try:
            k = winreg.OpenKey(root, path, 0, winreg.KEY_READ | winreg.KEY_SET_VALUE)
            i, to_del = 0, []
            while True:
                try:
                    name, val, _ = winreg.EnumValue(k, i)
                except OSError:
                    break
                if isinstance(val, str) and base in val.lower():
                    to_del.append(name)
                    for m in _PATH_RE.findall(val):
                        copy_paths.add(os.path.normcase(m))
                i += 1
            for name in to_del:
                winreg.DeleteValue(k, name)
                log(f"Удалён автозапуск {path.rsplit(chr(92),1)[-1]}: {name}")
            winreg.CloseKey(k)
        except OSError:
            pass

    # файлы Startup
    try:
        for fn in os.listdir(STARTUP_DIR):
            if fn == "guard.lnk":
                continue
            fp = os.path.join(STARTUP_DIR, fn)
            try:
                with open(fp, "r", errors="ignore") as f:
                    content = f.read()
                if base in content.lower():
                    for m in _PATH_RE.findall(content):
                        copy_paths.add(os.path.normcase(m))
                    os.remove(fp)
                    log(f"Удалён файл автозапуска: {fn}")
            except OSError:
                pass
    except OSError:
        pass

    # задачи schtasks
    r = subprocess.run(["schtasks", "/Query", "/FO", "LIST", "/V"],
                       capture_output=True, text=True, creationflags=0x08000000)
    cur = None
    for ln in (r.stdout or "").splitlines():
        s = ln.strip()
        if s.startswith("TaskName:"):
            cur = s.split(":", 1)[1].strip()
        elif s.startswith("Task To Run:") and cur and cur.strip("\\") != "GuardSentinel":
            if base in s.lower():
                for m in _PATH_RE.findall(s):
                    copy_paths.add(os.path.normcase(m))
                subprocess.run(["schtasks", "/Delete", "/TN", cur, "/F"],
                               capture_output=True, creationflags=0x08000000)
                log(f"Удалена задача автозапуска: {cur}")

    # убить ВСЕ запущенные копии по имени процесса (и Temp, и Roaming, и watchdog)
    subprocess.run(["taskkill", "/F", "/T", "/IM", os.path.basename(image_path)],
                   capture_output=True, creationflags=0x08000000)

    # удалить сами файлы копий (после kill)
    for p in copy_paths:
        try:
            if os.path.exists(p) and os.path.normcase(p) != os.path.normcase(
                    os.path.abspath(__file__)):
                os.remove(p)
                log(f"Удалён файл локера: {p}")
                # попробовать убрать папку-маскировку WindowsUpdateService, если пуста
                d = os.path.dirname(p)
                if d.lower().endswith("windowsupdateservice") and not os.listdir(d):
                    os.rmdir(d)
        except OSError:
            pass


# =======================================================================
#  ПАНИК-КЛАВИША
# =======================================================================
def register_panic_hotkey() -> bool:
    MOD_ALT, MOD_CONTROL, MOD_NOREPEAT, VK_K = 0x0001, 0x0002, 0x4000, 0x4B
    return bool(user32.RegisterHotKey(None, 1,
                                      MOD_ALT | MOD_CONTROL | MOD_NOREPEAT, VK_K))


# =======================================================================
#  ГЛАВНЫЙ ЦИКЛ
# =======================================================================
def main_loop() -> None:
    log(f"guard запущен (админ={is_admin()}). Паник-клавиша: Ctrl+Alt+K. Лог: {LOG_PATH}")
    if not is_admin():
        log("Без админа: убийство локеров, Defender CFA и правка HKLM недоступны. "
            "Лучше перезапусти от администратора.")
    try:
        kernel32.SetPriorityClass(kernel32.GetCurrentProcess(), 0x00000080)  # HIGH
    except Exception:
        pass
    enable_defender_cfa()
    backup_safeboot()
    if not safeboot_ok():
        log("ВНИМАНИЕ: ключи SafeBoot повреждены на старте.")
    winre_backup()
    expected = plant_canaries()
    if not register_panic_hotkey():
        log("Ctrl+Alt+K занята — паник-клавиша недоступна, остальное работает.")

    msg = wt.MSG()
    WM_HOTKEY, WM_CLOSE = 0x0312, 0x0010
    last = 0.0
    last_winre = 0.0
    last_vss = 0.0
    while True:
        if user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, 1):
            if msg.message == WM_HOTKEY:
                hwnd = user32.GetForegroundWindow()
                log(f"Паник-клавиша: закрываю окно '{_title(hwnd)}'")
                user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)
            user32.TranslateMessage(ctypes.byref(msg))
            user32.DispatchMessageW(ctypes.byref(msg))

        now = time.time()
        if now - last >= SCAN_INTERVAL:
            tampered = fix_keyboard_and_taskmgr()
            wins = find_locker_windows()
            if wins:
                for hwnd, pid, img in wins:
                    if is_admin():
                        log(f"ЛОКЕР: pid={pid} image='{img}' — чищу автозапуск и убиваю.")
                        purge_persistence(img)
                        kill_tree(pid)
                    else:
                        log(f"Подозрительное полноэкранное окно pid={pid} '{_title(hwnd)}' "
                            f"— без админа только закрываю. Нажми Ctrl+Alt+K.")
                        user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)
            elif tampered:
                log("Подделка политик обнаружена — возвращено в 0.")

            tripped = canary_tripped(expected)
            if tripped:
                react("\n  " + "\n  ".join(tripped))
                time.sleep(10)
                expected = plant_canaries()
            if not safeboot_ok():
                log("SafeBoot повреждён — восстанавливаю.")
                restore_safeboot()
            last = now

        if now - last_winre >= WINRE_INTERVAL:
            winre_protect()
            last_winre = now

        if now - last_vss >= VSS_INTERVAL:
            vss_protect()
            last_vss = now
        time.sleep(0.1)


if __name__ == "__main__":
    if os.name != "nt":
        sys.exit("Только для Windows 10/11.")
    if "--uninstall" in sys.argv:
        uninstall_autostart()
        sys.exit(0)
    if "--install-system" in sys.argv:
        install_system_task()
    if "--no-install" not in sys.argv:
        install_autostart()
    try:
        main_loop()
    except KeyboardInterrupt:
        log("Остановлено пользователем.")
