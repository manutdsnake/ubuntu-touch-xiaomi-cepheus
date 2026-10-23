# Cepheus Remote backend: sends IR through /dev/lirc0 (Mi 9 IR blaster).
import fcntl
import json
import os
import struct
import threading
import time

import irproto

HERE = os.path.dirname(os.path.abspath(__file__))
DB = json.load(open(os.path.join(HERE, "tvcodes.json")))
LIRC = "/dev/lirc0"
LIRC_SET_SEND_CARRIER = 0x40046913

_state = {"running": False, "done": 0, "total": 0, "cancel": False, "last": ""}


def _encode(c):
    if c[0] == "raw":
        return c[1], c[2]
    return irproto.PARSED[c[0]](c[1], c[2])


def _transmit(fd, carrier, timings, repeats=2):
    try:
        fcntl.ioctl(fd, LIRC_SET_SEND_CARRIER, struct.pack("I", int(carrier)))
    except OSError:
        pass  # driver with a fixed carrier
    data = struct.pack("%dI" % len(timings), *timings)
    for i in range(repeats):
        os.write(fd, data)
        if i + 1 < repeats:
            time.sleep(0.04)


def brands():
    return sorted(DB["brands"].keys(), key=str.lower)


def remotes(brand):
    return sorted(DB["brands"].get(brand, {}).keys())


def buttons(brand, remote):
    return sorted(DB["brands"][brand][remote].keys())


def universal_keys():
    return {k: len(v) for k, v in DB["universal"].items()}


def send(brand, remote, button):
    c = DB["brands"][brand][remote][button]
    try:
        fd = os.open(LIRC, os.O_WRONLY)
    except OSError as e:
        return "IR: %s" % e.strerror
    try:
        f, t = _encode(c)
        _transmit(fd, f, t)
        return "poslano: %s (%s, %d Hz)" % (button, c[0], f)
    except OSError as e:
        return "IR greška: %s" % e.strerror
    finally:
        os.close(fd)


def _universal_worker(key, start):
    codes = DB["universal"].get(key, [])
    _state.update(running=True, done=start, total=len(codes), cancel=False)
    try:
        fd = os.open(LIRC, os.O_WRONLY)
    except OSError as e:
        _state.update(running=False, last="IR: %s" % e.strerror)
        return
    try:
        for i in range(start, len(codes)):
            if _state["cancel"]:
                break
            c = codes[i]
            try:
                f, t = _encode(c)
                _transmit(fd, f, t, repeats=1)
            except OSError:
                pass
            _state["done"] = i + 1
            _state["last"] = "%s %d/%d (%s)" % (key, i + 1, len(codes), c[0])
            time.sleep(0.12)
    finally:
        os.close(fd)
        _state["running"] = False


def universal_start(key, start=0):
    if _state["running"]:
        return False
    threading.Thread(target=_universal_worker, args=(key, int(start)), daemon=True).start()
    return True


def universal_stop():
    _state["cancel"] = True


def universal_state():
    return dict(_state)


def universal_one(key, idx):
    codes = DB["universal"].get(key, [])
    if not 0 <= idx < len(codes):
        return "nema koda %d" % idx
    try:
        fd = os.open(LIRC, os.O_WRONLY)
    except OSError as e:
        return "IR: %s" % e.strerror
    try:
        f, t = _encode(codes[idx])
        _transmit(fd, f, t)
        return "%s kod %d/%d (%s)" % (key, idx + 1, len(codes), codes[idx][0])
    finally:
        os.close(fd)
