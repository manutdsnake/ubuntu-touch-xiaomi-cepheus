# Backend for Cepheus Test: things QML cannot reach by itself.
import glob
import math
import os
import struct
import subprocess
import wave

ENV = dict(os.environ)
TMP = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "cepheus-test")
os.makedirs(TMP, exist_ok=True)


def _run(cmd, timeout=10):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=ENV)
        return (r.stdout + r.stderr).strip()
    except Exception as e:  # noqa: BLE001 - report anything to the UI
        return "greška: %s" % e


def _read(path, default="?"):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


# ---------------------------------------------------------------- audio

def tone(freq=1000, seconds=2.0, name="tone"):
    """A sine wav in TMP; returns its path."""
    path = os.path.join(TMP, "%s-%d.wav" % (name, freq))
    rate = 48000
    n = int(rate * seconds)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for i in range(n):
            v = int(0.6 * 32767 * math.sin(2 * math.pi * freq * i / rate))
            frames += struct.pack("<hh", v, v)
        w.writeframes(bytes(frames))
    return path


def _droid(kind):
    """First droid-card sink or (non-monitor) source: names differ per port."""
    for line in _run(["pactl", "list", kind, "short"]).splitlines():
        f = line.split("\t")
        if len(f) > 2 and "droid" in f[2] and not f[1].endswith(".monitor"):
            return f[1]
    return "sink.primary_output" if kind == "sinks" else "source.primary_input"


def device():
    lines = _run(["device-info", "get", "Name"]).splitlines()
    return lines[-1].strip() if lines else "?"


def play(freq, port):
    """Play a tone on the given primary-output port (speaker / earpiece)."""
    sink = _droid("sinks")
    out = _run(["pactl", "set-sink-port", sink, "output-" + port])
    res = _run(["paplay", "-d", sink, tone(freq)], timeout=15)
    _run(["pactl", "set-sink-port", sink, "output-speaker"])
    return ("port %s: %s %s" % (port, out or "ok", res)).strip()


def record(source_port, seconds=4):
    src = _droid("sources")
    _run(["pactl", "set-source-port", src, "input-" + source_port])
    path = os.path.join(TMP, "rec-%s.wav" % source_port)
    _run(["timeout", str(seconds), "parecord", "-d", src, "--file-format=wav", path],
         timeout=seconds + 5)
    size = os.path.getsize(path) if os.path.exists(path) else 0
    # Rough level check: peak of the recording.
    peak = 0
    try:
        with wave.open(path) as w:
            data = w.readframes(w.getnframes())
            width = w.getsampwidth()
            if width == 2 and data:
                vals = struct.unpack("<%dh" % (len(data) // 2), data)
                peak = max(abs(v) for v in vals[len(vals) // 10:]) if vals else 0
    except Exception:  # noqa: BLE001
        pass
    return {"path": path, "bytes": size, "peak": peak}


def playback(path):
    sink = _droid("sinks")
    _run(["pactl", "set-sink-port", sink, "output-speaker"])
    return _run(["paplay", "-d", sink, path], timeout=15) or "ok"


# ---------------------------------------------------------------- hardware

def battery():
    b = "/sys/class/power_supply/battery/"
    info = {k: _read(b + k) for k in
            ("capacity", "status", "health", "voltage_now", "current_now", "temp",
             "charge_full", "charge_full_design", "cycle_count", "charge_type")}
    for k in ("voltage_now", "current_now"):
        try:
            info[k] = "%.3f" % (int(info[k]) / 1e6)
        except ValueError:
            pass
    try:
        info["temp"] = "%.1f" % (int(info["temp"]) / 10)
    except ValueError:
        pass
    info["usb_online"] = _read("/sys/class/power_supply/usb/online")
    info["usb_type"] = _read("/sys/class/power_supply/usb/real_type",
                             _read("/sys/class/power_supply/usb/type"))
    info["typec"] = _read("/sys/class/power_supply/usb/typec_mode")
    info["wireless"] = _read("/sys/class/power_supply/wireless/present",
                             _read("/sys/class/power_supply/idt/present", "?"))
    info["wireless_online"] = _read("/sys/class/power_supply/wireless/online",
                                    _read("/sys/class/power_supply/idt/online", "?"))
    return info


def flash(on):
    v = "255" if on else "0"
    msgs = []
    for p in ("/sys/class/leds/led:torch_0/brightness", "/sys/class/leds/led:torch_1/brightness",
              "/sys/class/leds/led:switch_0/brightness"):
        try:
            with open(p, "w") as f:
                f.write(v)
        except OSError as e:
            msgs.append("%s: %s" % (os.path.basename(os.path.dirname(p)), e.strerror))
    return "; ".join(msgs) or ("upaljeno" if on else "ugašeno")


def ir_blast():
    """Send a burst of NEC-like pulses; watch the IR LED through a camera."""
    try:
        fd = os.open("/dev/lirc0", os.O_WRONLY)
    except OSError as e:
        return "/dev/lirc0: %s" % e.strerror
    try:
        # LIRC_SET_SEND_CARRIER = _IOW('i', 0x13, __u32)
        import fcntl
        try:
            fcntl.ioctl(fd, 0x40046913, struct.pack("I", 38000))
        except OSError:
            pass
        pulses = [9000, 4500] + [560, 560, 560, 1690] * 16 + [560]
        for _ in range(20):
            os.write(fd, struct.pack("%dI" % len(pulses), *pulses))
        return "poslano 20 paketa (38 kHz) - pogledaj IR diodu kroz kameru"
    except OSError as e:
        return "slanje: %s" % e.strerror
    finally:
        os.close(fd)


def connectivity():
    out = {}
    out["wifi"] = _run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"])
    out["wifi_signal"] = _run(["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,FREQ dev wifi | grep '^\\*'"])
    out["ip"] = _run(["sh", "-c", "ip -br addr | grep -E ' UP | UNKNOWN ' | grep -v '^lo'"])
    out["bt"] = _run(["sh", "-c", "bluetoothctl show | grep -E 'Controller|Name|Powered|Discovering'"])
    out["bt_scan"] = ""
    out["modem"] = _run(["sh", "-c",
                         "/usr/share/ofono/scripts/list-modems 2>/dev/null | grep -E "
                         "'^\\[|Powered|Online|Serial|Revision|Name =|Strength|Technology|"
                         "MobileNetworkCode|MobileCountryCode|Status|CardIdentifier|SubscriberIdentity' "
                         "| sed 's/^ *//'"])
    out["nfc"] = _run(["sh", "-c",
                       "ls -l /dev/nq-nci 2>&1; systemctl is-active nfcd; "
                       "dbus-send --system --print-reply --dest=org.sailfishos.nfc.daemon / "
                       "org.sailfishos.nfc.Daemon.GetAdapters 2>&1 | tail -n +2"])
    out["gps"] = _run(["sh", "-c", "systemctl is-active lomiri-location-service 2>&1"])
    return out


def bt_scan():
    return _run(["sh", "-c", "bluetoothctl --timeout 8 scan on >/dev/null 2>&1; bluetoothctl devices | head -15"],
                timeout=15)


def wifi_scan():
    return _run(["sh", "-c", "nmcli -t -f SSID,SIGNAL,FREQ dev wifi list --rescan yes | head -15"], timeout=20)


def system_info():
    return {
        "kernel": _run(["uname", "-r"]),
        "failed": _run(["systemctl", "--failed", "--no-legend", "--plain"]) or "nijedan",
        "fp": _run(["sh", "-c", "systemctl is-active biometryd; cat /run/biometryd/udfps-active 2>/dev/null"]),
        "cameras": _run(["sh", "-c", "ls /dev/video* 2>/dev/null | wc -l"]),
        "storage": _run(["sh", "-c", "df -h /userdata | tail -1"]),
        "mem": _run(["sh", "-c", "free -m | sed -n 2p"]),
        "uptime": _run(["uptime", "-p"]),
    }


def nfc_state():
    """Live NFC adapter state and any tags nfcd currently sees."""
    def call(path, iface, method):
        return _run(["dbus-send", "--system", "--print-reply=literal", "--dest=org.sailfishos.nfc.daemon",
                     path, "%s.%s" % (iface, method)], timeout=3)
    powered = call("/nfc0", "org.sailfishos.nfc.Adapter", "GetPowered").split()[-1:]
    present = call("/nfc0", "org.sailfishos.nfc.Adapter", "GetTargetPresent").split()[-1:]
    mode = call("/nfc0", "org.sailfishos.nfc.Adapter", "GetMode").split()[-1:]
    tags = [t for t in call("/nfc0", "org.sailfishos.nfc.Adapter", "GetTags").split() if t.startswith("/nfc0/")]
    info = []
    for t in tags:
        info.append(t + ":\n" + call(t, "org.sailfishos.nfc.Tag", "GetAll"))
    return {"powered": " ".join(powered), "present": " ".join(present), "mode": " ".join(mode),
            "tags": "\n".join(info) or "nema"}
