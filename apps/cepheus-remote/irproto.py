# Infrared protocol encoders -> (carrier Hz, [mark, space, mark, ...] in us).
# Address/command follow Flipper Zero's .ir "parsed" conventions (little-endian
# byte fields), so the Flipper-IRDB database can be used as is.


def _bits(value, n, msb=False):
    r = [(value >> i) & 1 for i in range(n)]
    return r[::-1] if msb else r


def _pulse_distance(bits, mark, zero_space, one_space):
    out = []
    for b in bits:
        out += [mark, one_space if b else zero_space]
    return out


def _nec_frame(bits, hdr=(9000, 4500)):
    return list(hdr) + _pulse_distance(bits, 560, 560, 1690) + [560]


def nec(addr, cmd, carrier=38000):
    a, c = addr & 0xFF, cmd & 0xFF
    bits = _bits(a, 8) + _bits(a ^ 0xFF, 8) + _bits(c, 8) + _bits(c ^ 0xFF, 8)
    return carrier, _nec_frame(bits)


def necext(addr, cmd):
    bits = _bits(addr & 0xFFFF, 16) + _bits(cmd & 0xFFFF, 16)
    return 38000, _nec_frame(bits)


def nec42(addr, cmd):
    a, c = addr & 0x1FFF, cmd & 0xFF
    bits = _bits(a, 13) + _bits(a ^ 0x1FFF, 13) + _bits(c, 8) + _bits(c ^ 0xFF, 8)
    return 38000, _nec_frame(bits)


def samsung32(addr, cmd):
    a, c = addr & 0xFF, cmd & 0xFF
    bits = _bits(a, 8) + _bits(a, 8) + _bits(c, 8) + _bits(c ^ 0xFF, 8)
    return 38000, _nec_frame(bits, hdr=(4500, 4500))


def _manchester(levels, half):
    """levels: list of (mark?, duration) half-bits -> merged mark/space list."""
    out, cur, dur = [], None, 0
    for is_mark, d in levels:
        if cur is None or is_mark == cur:
            cur, dur = is_mark, dur + d
        else:
            out.append((cur, dur))
            cur, dur = is_mark, d
    out.append((cur, dur))
    # must start with a mark and end with a mark
    while out and not out[0][0]:
        out.pop(0)
    while out and not out[-1][0]:
        out.pop()
    return [d for _, d in out]


def rc5(addr, cmd, ext=False):
    t = 889
    field = 0 if (ext and cmd >= 64) else 1
    bits = [1, field, 0] + _bits(addr & 0x1F, 5, msb=True) + _bits(cmd & 0x3F, 6, msb=True)
    lv = []
    for b in bits:  # RC5: 1 = space then mark, 0 = mark then space
        lv += [(False, t), (True, t)] if b else [(True, t), (False, t)]
    return 36000, _manchester(lv, t)


def rc6(addr, cmd):
    t = 444
    lv = [(True, 2666), (False, 889)]
    lv += [(True, t), (False, t)]           # start bit 1
    for b in (0, 0, 0):                     # mode 0
        lv += [(True, t), (False, t)] if b else [(False, t), (True, t)]
    lv += [(False, 2 * t), (True, 2 * t)]   # toggle 0, double length
    for b in _bits(addr & 0xFF, 8, msb=True) + _bits(cmd & 0xFF, 8, msb=True):
        lv += [(True, t), (False, t)] if b else [(False, t), (True, t)]
    return 36000, _manchester(lv, t)


def sirc(addr, cmd, abits):
    bits = _bits(cmd & 0x7F, 7) + _bits(addr, abits)
    frame = [2400, 600]
    for b in bits:
        frame += [1200 if b else 600, 600]
    frame = frame[:-1]
    # Sony wants the frame repeated; pad each to a 45 ms period.
    gap = max(45000 - sum(frame), 8000)
    return 40000, frame + [gap] + frame + [gap] + frame


def kaseikyo(addr, cmd):
    ident = (addr >> 24) & 3
    vendor = (addr >> 8) & 0xFFFF
    g1, g2 = (addr >> 4) & 0xF, addr & 0xF
    d = [vendor & 0xFF, vendor >> 8]
    vp = d[0] ^ d[1]
    vp = (vp & 0xF) ^ (vp >> 4)
    d.append((vp & 0xF) | (g1 << 4))
    d.append((g2 & 0xF) | ((cmd & 0xF) << 4))
    d.append((ident << 6) | ((cmd >> 4) & 0x3F))
    d.append(d[2] ^ d[3] ^ d[4])
    bits = []
    for byte in d:
        bits += _bits(byte, 8)
    return 37000, [3456, 1728] + _pulse_distance(bits, 432, 432, 1296) + [432]


def rca(addr, cmd):
    a, c = addr & 0xF, cmd & 0xFF
    bits = _bits(a, 4, msb=True) + _bits(c, 8, msb=True) + _bits(a ^ 0xF, 4, msb=True) + _bits(c ^ 0xFF, 8, msb=True)
    return 56000, [4000, 4000] + _pulse_distance(bits, 500, 1000, 2000) + [500]


def pioneer(addr, cmd):
    return nec(addr, cmd, carrier=40000)


def _le(hexbytes):
    b = bytes(int(x, 16) for x in hexbytes.split())
    return int.from_bytes(b, "little")


PARSED = {
    "NEC": lambda a, c: nec(a, c), "NECext": necext, "NEC42": nec42,
    "Samsung32": samsung32, "RC5": lambda a, c: rc5(a, c), "RC5X": lambda a, c: rc5(a, c, ext=True),
    "RC6": rc6, "SIRC": lambda a, c: sirc(a, c, 5), "SIRC15": lambda a, c: sirc(a, c, 8),
    "SIRC20": lambda a, c: sirc(a, c, 13), "Kaseikyo": kaseikyo, "RCA": rca, "Pioneer": pioneer,
}


def encode(sig):
    """sig: dict from a Flipper .ir entry -> (carrier, timings) or None."""
    if sig.get("type") == "raw":
        t = [abs(int(x)) for x in sig["data"].split()]
        if len(t) % 2 == 0:
            t = t[:-1]
        return int(sig.get("frequency", 38000)), t
    fn = PARSED.get(sig.get("protocol"))
    if not fn:
        return None
    return fn(_le(sig["address"]), _le(sig["command"]))


def parse_ir_file(text):
    """Flipper .ir text -> list of dicts (name, type, protocol/address/command or frequency/data)."""
    out, cur = [], None
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        k, v = line.split(":", 1)
        k, v = k.strip(), v.strip()
        if k == "name":
            cur = {"name": v}
            out.append(cur)
        elif cur is not None:
            cur[k] = v
    return out
