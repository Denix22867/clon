"""Собирает открываемый в редакторе проект Godot из распакованного pck.

python3 -I build_project.py <out_dir_from_gdre> <project_dir>
"""
import os
import re
import shutil
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assets  # noqa: E402
import gdre  # noqa: E402


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = 'wb' if isinstance(data, bytes) else 'w'
    with open(path, mode, **({} if mode == 'wb' else {'encoding': 'utf-8'})) as f:
        f.write(data)


def remap_target(import_text):
    return re.search(r'path="res://(\.godot/imported/[^"]+)"', import_text).group(1)


def uid_of(import_text):
    m = re.search(r'uid="(uid://[^"]+)"', import_text)
    return m.group(1) if m else None


def texture_import(uid):
    lines = ['[remap]', '', 'importer="texture"', 'type="CompressedTexture2D"']
    if uid:
        lines.append(f'uid="{uid}"')
    return '\n'.join(lines) + '\n'


def project_godot(raw):
    b = open(os.path.join(raw, 'project.binary'), 'rb').read()
    assert b[:4] == b'ECFG'
    (n,) = struct.unpack_from('<I', b, 4)
    p, sections = 8, {}
    for _ in range(n):
        (kl,) = struct.unpack_from('<I', b, p); p += 4
        key = b[p:p + kl].decode(); p += kl
        (vl,) = struct.unpack_from('<I', b, p); p += 4
        v = b[p:p + vl]; p += vl
        t = struct.unpack_from('<I', v, 0)[0] & 0xFF
        if t == 34:  # PackedStringArray
            (cnt,) = struct.unpack_from('<I', v, 4); q, items = 8, []
            for _ in range(cnt):
                s, q = gdre.dec_str(v, q); items.append(gdre.esc(s.rstrip('\0')))
            text = 'PackedStringArray(' + ', '.join(items) + ')'
        elif t == 20:  # Color
            text = 'Color(' + ', '.join(f'{x:.6g}' for x in struct.unpack_from('<4f', v, 4)) + ')'
        else:
            val, _ = gdre.dec_variant(v, 0)
            text = gdre.lit(val)
        sec, _, prop = key.partition('/')
        sections.setdefault(sec, []).append(f'{prop}={text}')
    out = ['; Восстановлено из project.binary экспортированной сборки.', '', 'config_version=5', '']
    for sec, props in sections.items():
        out += [f'[{sec}]', ''] + props + ['']
    return '\n'.join(out)


def main(src, dst):
    raw, gd = os.path.join(src, 'raw'), os.path.join(src, 'src')
    if os.path.exists(dst):
        shutil.rmtree(dst)
    write(os.path.join(dst, 'project.godot'), project_godot(raw))

    # Скрипты (декомпилированные) с двумя правками путей к ресурсам, которые нельзя вернуть в исходный формат.
    for f in sorted(os.listdir(os.path.join(gd, 'scripts'))):
        code = open(os.path.join(gd, 'scripts', f), encoding='utf-8').read()
        if f == 'fantasy_main.gd':
            old = 'load("res://assets/ui/" + name + ".svg")'
            assert old in code
            code = code.replace(old, 'load("res://assets/ui/" + name + ".png")')
        if f == 'painted_world.gd':
            for m in ('painted_battle', 'mining'):
                old = f'load("res://assets/models/{m}.glb")'
                assert old in code
                code = code.replace(old, f'load("res://assets/models/{m}.scn")')
        write(os.path.join(dst, 'scripts', f), code)

    # Главная сцена: один узел Node3D «Iskra» со скриптом fantasy_main.gd (см. export-…-main.scn).
    write(os.path.join(dst, 'scenes', 'main.tscn'),
          '[gd_scene load_steps=2 format=3]\n\n'
          '[ext_resource type="Script" path="res://scripts/fantasy_main.gd" id="1"]\n\n'
          '[node name="Iskra" type="Node3D"]\nscript = ExtResource("1")\n')

    for root, _, files in os.walk(os.path.join(raw, 'assets')):
        for f in files:
            path = os.path.join(root, f)
            rel = os.path.relpath(path, raw)
            if not f.endswith('.import'):
                shutil.copy(path, os.path.join(dst, rel)) if os.makedirs(os.path.dirname(os.path.join(dst, rel)), exist_ok=True) is None else None
                continue
            text = open(path, encoding='utf-8').read()
            res = rel[:-len('.import')]
            data = open(os.path.join(raw, remap_target(text)), 'rb').read()
            if res.endswith(('.png', '.svg')) and res != 'assets/icon.svg':
                png, _ = assets.ctex_to_png(data)
                out = res if res.endswith('.png') else res[:-4] + '.png'
                write(os.path.join(dst, out), png)
                write(os.path.join(dst, out + '.import'), texture_import(uid_of(text) if res.endswith('.png') else None))
            elif res.endswith('.ttf'):
                write(os.path.join(dst, res), assets.ttf_from(assets.rscc(data)))
            elif res.endswith('.glb'):
                # Импортированная сцена модели: исходный сжатый бинарный ресурс (RSCC) Godot читает как .scn.
                # В репозитории она пересохранена в текстовый .tscn самим Godot (см. README).
                write(os.path.join(dst, res[:-4] + '.scn'), data)
            elif res == 'assets/icon.svg':
                pass  # исходный svg лежит рядом и уже скопирован
            else:
                raise ValueError(res)

    for root, _, files in os.walk(os.path.join(raw, 'web')):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), raw)
            write(os.path.join(dst, rel), open(os.path.join(root, f), 'rb').read())


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
