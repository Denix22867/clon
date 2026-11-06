"""Проверка декомпиляции: токенизируем восстановленный .gd и сравниваем с потоком токенов из .gdc.

python3 -I verify.py <raw_dir_with_gdc> <src_dir_with_gd>
"""
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gdre  # noqa: E402
import zstandard  # noqa: E402

T = gdre.T
KEYWORDS = {k: T[k] for k in 'and or not if elif else for while break continue pass return match when as assert await breakpoint class class_name const enum extends func in is namespace preload self signal static super trait var void yield PI TAU INF NAN'.split()}
LITWORDS = {'true': True, 'false': False, 'null': None}
OPS = sorted([k for k in gdre.TOKENS if not k.isalnum() and k not in ('EMPTY',) and not k.isupper() and k != 'class_name'], key=len, reverse=True)


def orig_tokens(buf):
    version, dsize = struct.unpack_from('<II', buf, 4)
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
        v, p = gdre.dec_variant(b, p); consts.append(v)
    p += 16 * nlines
    out = []
    for _ in range(ntok):
        if b[p] & 0x80:
            (tt,) = struct.unpack_from('<I', b, p); p += 4
        else:
            tt = b[p]; p += 1
        (line,) = struct.unpack_from('<I', b, p); p += 4
        k, idx = tt & 0x7F, tt >> 8
        if k in (T['IDENTIFIER'], T['ANNOTATION']):
            v = idents[idx]
            if k == T['ANNOTATION'] and v.startswith('@'): v = v[1:]
        elif k == T['LITERAL']:
            v = consts[idx]
        else:
            v = None
        out.append((k, norm(v) if k == T["LITERAL"] else v, line))
    return out


def norm(v):
    if isinstance(v, float) and v == int(v) and abs(v) < 1e15:
        return ('f', v)
    if isinstance(v, bool) or v is None:
        return ('b', v)
    if isinstance(v, int):
        return ('i', v)
    if isinstance(v, float):
        return ('f', struct.unpack('<d', struct.pack('<d', v))[0])
    return v


PRECEDE_BIN = {T[k] for k in ['IDENTIFIER', 'LITERAL', 'self', ']', '}', ')', 'PI', 'TAU', 'INF', 'NAN']}
NUM = re.compile(r'0x[0-9a-fA-F_]+|0b[01_]+|(?:\d[\d_]*\.?[\d_]*|\.\d[\d_]*)(?:[eE][+-]?\d+)?')
ESC = {'n': '\n', 't': '\t', 'r': '\r', '\\': '\\', '"': '"', "'": "'", '0': '\0', 'a': '\a', 'b': '\b', 'f': '\f', 'v': '\v'}


def lex(src):
    i, line, out, n = 0, 1, [], len(src)
    while i < n:
        c = src[i]
        if c == '\n':
            line += 1; i += 1; continue
        if c in ' \t\r':
            i += 1; continue
        if c == '\\' and src[i + 1] == '\n':
            line += 1; i += 2; continue
        if c == '#':
            while i < n and src[i] != '\n': i += 1
            continue
        if c == '@':
            m = re.match(r'@([A-Za-z_]\w*)', src[i:]); out.append((T['ANNOTATION'], m.group(1), line)); i += m.end(); continue
        prefix = None
        if c in '&^r' and i + 1 < n and src[i + 1] in '"\'':
            prefix = c; i += 1; c = src[i]
        if c in '"\'':
            start_line = line
            triple = src[i:i + 3] in ('"""', "'''")
            q = src[i:i + 3] if triple else c
            i += len(q)
            s = []
            while not src.startswith(q, i):
                ch = src[i]
                if ch == '\\' and prefix != 'r':
                    e = src[i + 1]
                    if e == 'u':
                        s.append(chr(int(src[i + 2:i + 6], 16))); i += 6; continue
                    if e == 'U':
                        s.append(chr(int(src[i + 2:i + 8], 16))); i += 8; continue
                    if e == '\n':
                        line += 1; i += 2; continue
                    s.append(ESC[e]); i += 2; continue
                if ch == '\n': line += 1
                s.append(ch); i += 1
            i += len(q)
            v = ''.join(s)
            if prefix in ('&', '^'): v = (prefix, v)
            out.append((T['LITERAL'], v, start_line)); continue
        sign = 1
        if c in '+-' and i + 1 < n and src[i + 1].isdigit() and not (out and out[-1][0] in PRECEDE_BIN):
            sign = -1 if c == '-' else 1; i += 1; c = src[i]
        if c.isdigit() or (c == '.' and i + 1 < n and src[i + 1].isdigit()):
            m = NUM.match(src, i); t = m.group(0).replace('_', '')
            if sign < 0: t = '-' + t
            neg = t.startswith('-'); t = t.lstrip('-')
            if t.startswith('0x'): v = int(t, 16)
            elif t.startswith('0b'): v = int(t[2:], 2)
            elif any(x in t for x in '.eE'): v = float(t)
            else: v = int(t)
            if neg: v = -v
            out.append((T['LITERAL'], norm(v), line)); i = m.end(); continue
        if c.isalpha() or c == '_' or ord(c) > 127:
            m = re.match(r'[^\W\d]\w*', src[i:]); w = m.group(0); i += m.end()
            if w in LITWORDS: out.append((T['LITERAL'], norm(LITWORDS[w]), line))
            elif w == '_': out.append((T['_'], None, line))
            elif w in KEYWORDS: out.append((KEYWORDS[w], None, line))
            elif w == 'class_name': out.append((T['class_name'], None, line))
            else: out.append((T['IDENTIFIER'], w, line))
            continue
        for op in OPS:
            if src.startswith(op, i):
                out.append((T[op], None, line)); i += len(op); break
        else:
            raise ValueError(f'line {line}: unexpected {c!r}')
    return out


def norm_lit(tok):
    k, v, l = tok
    if k == T['LITERAL'] and isinstance(v, str):
        return tok
    if k == T['LITERAL'] and isinstance(v, tuple) and v and v[0] in ('&', '^'):
        return tok
    return tok


def main(raw, src):
    ok = True
    for root, _, files in os.walk(raw):
        for f in sorted(files):
            if not f.endswith('.gdc'): continue
            rel = os.path.relpath(os.path.join(root, f), raw)
            a = orig_tokens(open(os.path.join(root, f), 'rb').read())
            b = lex(open(os.path.join(src, rel[:-1]), encoding='utf-8').read())
            diff = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), None)
            if diff is None and len(a) == len(b):
                print(f'OK   {rel}: {len(a)} tokens')
            else:
                ok = False
                i = diff if diff is not None else min(len(a), len(b))
                print(f'DIFF {rel} at token {i}: orig={a[i:i+3]} got={b[i:i+3]} (len {len(a)} vs {len(b)})')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
