"""Распаковка Godot 4 .pck (формат v3/v4) и декомпиляция .gdc (tokenizer v101).

Использование: python3 -I gdre.py <index.pck> <out_dir>
"""
import math
import os
import struct
import sys

import zstandard

TOKENS = """EMPTY ANNOTATION IDENTIFIER LITERAL < <= > >= == != and or not && || ! & | ~ ^ << >> + - * ** / % =
+= -= *= **= /= %= <<= >>= &= |= ^= if elif else for while break continue pass return match when as assert await
breakpoint class class_name const enum extends func in is namespace preload self signal static super trait var void
yield [ ] { } ( ) , ; . .. ... : $ -> _ NEWLINE INDENT DEDENT PI TAU INF NAN VCS_CONFLICT_MARKER ` ? ERROR EOF""".split()
T = {name: i for i, name in enumerate(TOKENS)}
assert len(TOKENS) == 100, len(TOKENS)

# ---------------------------------------------------------------- PCK
def read_pck(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[:4] == b'GDPC', 'not a pck'
    ver, vmaj, vmin, vpat, flags = struct.unpack_from('<5I', data, 4)
    assert ver in (3, 4), ver
    assert not flags & 1, 'encrypted directory'
    file_base, dir_ofs = struct.unpack_from('<QQ', data, 24)
    pos = dir_ofs
    (count,) = struct.unpack_from('<I', data, pos); pos += 4
    files = []
    for _ in range(count):
        (sl,) = struct.unpack_from('<I', data, pos); pos += 4
        name = data[pos:pos + sl].rstrip(b'\0').decode('utf-8'); pos += sl
        ofs, size = struct.unpack_from('<QQ', data, pos); pos += 16
        pos += 16  # md5
        (fflags,) = struct.unpack_from('<I', data, pos); pos += 4
        if fflags & 2:
            continue
        assert not fflags & 1, f'encrypted file {name}'
        files.append((name, data[file_base + ofs:file_base + ofs + size]))
    return (vmaj, vmin, vpat), files

# ---------------------------------------------------------------- Variant
def dec_str(b, p):
    (n,) = struct.unpack_from('<I', b, p); p += 4
    s = b[p:p + n].decode('utf-8'); p += n + (-n % 4)
    return s, p

def dec_variant(b, p):
    (h,) = struct.unpack_from('<I', b, p); p += 4
    t, f64 = h & 0xFF, bool(h & (1 << 16))
    if t == 0: return None, p
    if t == 1: return bool(struct.unpack_from('<I', b, p)[0]), p + 4
    if t == 2:
        return (struct.unpack_from('<q', b, p)[0], p + 8) if f64 else (struct.unpack_from('<i', b, p)[0], p + 4)
    if t == 3:
        return (struct.unpack_from('<d', b, p)[0], p + 8) if f64 else (struct.unpack_from('<f', b, p)[0], p + 4)
    if t == 4:
        s, p = dec_str(b, p); return s, p
    if t == 21:
        s, p = dec_str(b, p); return ('&', s), p
    if t == 22:
        nc, sc, fl = struct.unpack_from('<III', b, p); p += 12
        nc &= 0x7FFFFFFF
        if fl & 2: sc += 1
        parts = []
        for _ in range(nc + sc):
            s, p = dec_str(b, p); parts.append(s)
        path = ('/' if fl & 1 else '') + '/'.join(parts[:nc])
        if sc: path += ':' + ':'.join(parts[nc:])
        return ('^', path), p
    raise ValueError(f'unsupported literal variant type {t}')

def esc(s):
    out = []
    for ch in s:
        out.append({'\\': '\\\\', '"': '\\"', '\n': '\\n', '\t': '\\t', '\r': '\\r'}.get(ch, ch))
    return '"' + ''.join(out) + '"'

def fmt_float(x):
    if math.isinf(x): return 'INF' if x > 0 else '-INF'
    if math.isnan(x): return 'NAN'
    r = repr(x)
    if 'e' in r or 'E' in r:
        m, e = r.lower().split('e')
        if '.' not in m: m += '.0'
        return f'{m}e{int(e)}'
    return r

def lit(v):
    if v is None: return 'null'
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, int): return str(v)
    if isinstance(v, float): return fmt_float(v)
    if isinstance(v, str): return esc(v)
    if isinstance(v, tuple): return v[0] + esc(v[1])
    raise TypeError(v)

# ---------------------------------------------------------------- GDC
def decompile(buf):
    assert buf[:4] == b'GDSC'
    version, dsize = struct.unpack_from('<II', buf, 4)
    assert version == 101, f'tokenizer version {version}'
    b = zstandard.ZstdDecompressor().decompress(buf[12:], max_output_size=dsize) if dsize else buf[12:]
    nid, nconst, nlines, ntok = struct.unpack_from('<4I', b, 0)
    p = 16
    idents = []
    for _ in range(nid):
        (n,) = struct.unpack_from('<I', b, p); p += 4
        raw = bytes(x ^ 0xB6 for x in b[p:p + n * 4]); p += n * 4
        idents.append(''.join(chr(c) for c in struct.unpack(f'<{n}I', raw)))
    consts = []
    for _ in range(nconst):
        v, p = dec_variant(b, p); consts.append(v)
    lines, cols = {}, {}
    for _ in range(nlines):
        i, l = struct.unpack_from('<II', b, p); p += 8; lines[i] = l
    for _ in range(nlines):
        i, c = struct.unpack_from('<II', b, p); p += 8; cols[i] = c
    toks = []
    for _ in range(ntok):
        if b[p] & 0x80:
            (tt,) = struct.unpack_from('<I', b, p); p += 4
        else:
            tt = b[p]; p += 1
        (line,) = struct.unpack_from('<I', b, p); p += 4
        kind = tt & 0x7F
        idx = tt >> 8
        if kind in (T['IDENTIFIER'], T['ANNOTATION']):
            text = idents[idx]
            if kind == T['ANNOTATION'] and not text.startswith('@'): text = '@' + text
        elif kind in (T['LITERAL'], T['ERROR']):
            text = lit(consts[idx])
        else:
            text = TOKENS[kind]
        toks.append((kind, text, line))
    assert p == len(b), (p, len(b))
    return render(toks, cols)

WORDY = {T[k] for k in 'and or not if elif else for while break continue pass return match when as assert await breakpoint class class_name const enum extends func in is namespace preload self signal static super trait var void yield PI TAU INF NAN'.split()}
WORDY |= {T['IDENTIFIER'], T['ANNOTATION'], T['LITERAL']}
BINOPS = {T[k] for k in '< <= > >= == != && || & | ^ << >> + * ** / % = += -= *= **= /= %= <<= >>= &= |= ^= ->'.split()}
NO_SPACE_BEFORE = {T[k] for k in ') ] , ; . : ..'.split()}
NO_SPACE_AFTER = {T[k] for k in '( [ . $ ! ~ ..'.split()}

def render(toks, cols):
    out_lines = {}
    indent_stack = [1]
    depth_of_line = {}
    cur_line = None
    prev = None
    bracket = 0
    for i, (kind, text, line) in enumerate(toks):
        new_logical = i == 0 or i in cols
        if new_logical:
            col = cols.get(i, 1)
            if bracket == 0:
                while col < indent_stack[-1] and len(indent_stack) > 1:
                    indent_stack.pop()
                if col > indent_stack[-1]:
                    indent_stack.append(col)
                depth = len(indent_stack) - 1
            else:
                depth = len(indent_stack)  # continuation inside brackets
            cur_line = line
            out_lines.setdefault(line, ['\t' * depth, ''])
            prev = None
        elif line != cur_line:
            # implicit continuation (inside brackets / after backslash)
            if line not in out_lines:
                out_lines[line] = ['\t' * (len(indent_stack)), '']
            cur_line = line
            prev = None
        seg = out_lines[cur_line]
        if prev is not None and need_space(prev, kind, toks, i):
            seg[1] += ' '
        seg[1] += text
        if kind in (T['('], T['['], T['{']): bracket += 1
        elif kind in (T[')'], T[']'], T['}']): bracket = max(0, bracket - 1)
        prev = kind
    if not out_lines:
        return ''
    last = max(out_lines)
    res = []
    for ln in range(1, last + 1):
        if ln in out_lines:
            res.append(out_lines[ln][0] + out_lines[ln][1])
        else:
            res.append('')
    return '\n'.join(res) + '\n'

def need_space(prev, kind, toks, i):
    if kind in NO_SPACE_BEFORE:
        return False
    if prev in NO_SPACE_AFTER:
        return False
    if kind in (T['('],):
        # call vs grouping
        return prev not in (T['IDENTIFIER'], T[')'], T[']'], T['preload'], T['super'], T['self'], T['assert'], T['ANNOTATION'], T['func'], T['LITERAL'], T['await']) or prev == T['func']
    if kind == T['['] :
        return prev not in (T['IDENTIFIER'], T[')'], T[']'], T['LITERAL'], T['self'])
    if prev in (T['('], T['['], T['{']):
        return kind == T['{'] and False
    if kind in (T[']'], T[')'], T['}']):
        return kind == T['}']
    if prev in (T['-'], T['+']) and is_unary(toks, i - 1):
        # «-1» токенизатор Godot склеит в один литерал, поэтому отдельный
        # унарный минус перед числом сохраняем через пробел: «- 1».
        return kind == T['LITERAL'] and toks[i][1][:1].isdigit()
    if prev == T['ANNOTATION'] and kind == T['(']:
        return False
    return True

def is_unary(toks, j):
    if j == 0: return True
    pk = toks[j - 1][0]
    return pk in BINOPS or pk in (T['('], T['['], T['{'], T[','], T[':'], T['return'], T['-'], T['and'], T['or'], T['not'], T['in'], T['if'], T['elif'], T['while'], T['when'])

# ---------------------------------------------------------------- main
def main(pck, out):
    ver, files = read_pck(pck)
    print('Godot', '.'.join(map(str, ver)), 'files:', len(files))
    bad = []
    for name, data in files:
        rel = name.replace('res://', '', 1)
        dst = os.path.join(out, 'raw', rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, 'wb') as f:
            f.write(data)
        if rel.endswith('.gdc'):
            try:
                src = decompile(data)
            except Exception as e:  # noqa
                bad.append((rel, e)); continue
            d2 = os.path.join(out, 'src', rel[:-1])
            os.makedirs(os.path.dirname(d2), exist_ok=True)
            with open(d2, 'w', encoding='utf-8') as f:
                f.write(src)
    for rel, e in bad:
        print('FAILED', rel, e)

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
