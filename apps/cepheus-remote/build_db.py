#!/usr/bin/env python3
"""Flipper-IRDB TVs + Flipper's universal tv.ir -> tvcodes.json for Cepheus Remote."""
import glob, json, os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
import irproto

SRC = sys.argv[1]            # .../irdb
CANON = {
    "power": ["power", "pwr", "power_on", "on/off", "standby", "power_toggle"],
    "vol_up": ["vol_up", "volup", "vol+", "volume_up", "vol_+"], "vol_dn": ["vol_dn", "voldown", "vol-", "vol_down", "volume_down", "vol_-"],
    "mute": ["mute"], "ch_next": ["ch_next", "ch+", "ch_up", "chup", "channel_up", "prog+"],
    "ch_prev": ["ch_prev", "ch-", "ch_dn", "ch_down", "chdown", "channel_down", "prog-"],
    "up": ["up"], "down": ["down"], "left": ["left"], "right": ["right"], "ok": ["ok", "enter", "select"],
    "back": ["back", "return"], "home": ["home", "smart_hub", "smart"], "menu": ["menu"], "exit": ["exit"],
    "source": ["source", "input", "src", "av", "tv/av"], "info": ["info"], "guide": ["guide", "epg"],
    "play": ["play"], "pause": ["pause"], "stop": ["stop"], "netflix": ["netflix"],
    **{str(i): [str(i)] for i in range(10)},
}
LOOK = {a: k for k, al in CANON.items() for a in al}

def canon(name):
    n = name.strip().lower().replace(" ", "_")
    return LOOK.get(n, n)

def compact(sig):
    if sig.get("type") == "raw":
        f, t = irproto.encode(sig)
        return ["raw", f, t]
    if sig.get("protocol") not in irproto.PARSED:
        return None
    return [sig["protocol"], irproto._le(sig["address"]), irproto._le(sig["command"])]

db = {"brands": {}, "universal": {}}
for path in sorted(glob.glob(os.path.join(SRC, "TVs", "*", "*.ir"))):
    brand = os.path.basename(os.path.dirname(path)).replace("_", " ")
    remote = re.sub(r"\.ir$", "", os.path.basename(path)).replace("_", " ")
    buttons = {}
    for s in irproto.parse_ir_file(open(path, errors="replace").read()):
        c = compact(s)
        if c and irproto.encode(s):
            buttons.setdefault(canon(s["name"]), c)
    if buttons:
        db["brands"].setdefault(brand, {})[remote] = buttons

for s in irproto.parse_ir_file(open(os.path.join(SRC, "universal_tv.ir")).read()):
    c = compact(s)
    if c:
        db["universal"].setdefault(canon(s["name"]), []).append(c)

json.dump(db, open(os.path.join(os.path.dirname(__file__), "tvcodes.json"), "w"), separators=(",", ":"))
print("brands", len(db["brands"]), "remotes", sum(len(v) for v in db["brands"].values()),
      "universal", {k: len(v) for k, v in db["universal"].items()})
