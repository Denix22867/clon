"""Восстановление ресурсов из распакованного pck: ctex -> png, RSCC -> RSRC, fontdata -> ttf."""
import io, os, struct, sys, zlib
import zstandard
from PIL import Image

def rscc(b):
    assert b[:4] == b'RSCC'
    mode, bs, total = struct.unpack_from('<III', b, 4)
    n = total // bs + 1
    sizes = struct.unpack_from(f'<{n}I', b, 16)
    p, out = 16 + 4 * n, bytearray()
    for i, s in enumerate(sizes):
        want = min(bs, total - i * bs)
        chunk = b[p:p + s]; p += s
        if mode == 2:
            out += zstandard.ZstdDecompressor().decompress(chunk, max_output_size=want)
        elif mode == 1:
            out += zlib.decompress(chunk)
        else:
            raise ValueError(f'compression mode {mode}')
    assert len(out) == total, (len(out), total)
    return bytes(out)

def ctex_to_png(b):
    assert b[:4] == b'GST2'
    i = b.find(b'RIFF'); j = b.find(b'\x89PNG')
    k = min(x for x in (i, j) if x >= 0)
    (size,) = struct.unpack_from('<I', b, k - 4)
    img = Image.open(io.BytesIO(b[k:k + size])); img.load()
    out = io.BytesIO(); img.save(out, 'PNG', optimize=True)
    return out.getvalue(), img.size

def ttf_from(rsrc):
    # FontFile.data: PackedByteArray с TTF внутри; ищем sfnt-заголовок и длину перед ним
    for sig in (b'\x00\x01\x00\x00', b'OTTO'):
        k = 0
        while True:
            k = rsrc.find(sig, k + 1)
            if k < 0: break
            (n,) = struct.unpack_from('<I', rsrc, k - 4)
            ntab = struct.unpack_from('>H', rsrc, k + 4)[0]
            if 4 < ntab < 64 and k + n <= len(rsrc) and n > 1000:
                return rsrc[k:k + n]
    raise ValueError('ttf not found')
