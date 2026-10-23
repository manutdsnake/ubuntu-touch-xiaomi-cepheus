"""System Settings > Side button backend (pyotherside).

Reads and writes ~/.config/cepheus/sidebutton.json, which
/usr/libexec/cepheus-sidebutton re-reads on every press, and lists the
launchable apps with their names and icons.
"""
import configparser, glob, json, os, subprocess

CONFIG = os.path.expanduser("~/.config/cepheus/sidebutton.json")
DEFAULTS = {"single": "none", "double": "app:camera.ubports_camera", "long": "torch"}


def load():
    cfg = dict(DEFAULTS)
    try:
        with open(CONFIG) as f:
            cfg.update({k: v for k, v in json.load(f).items() if k in DEFAULTS})
    except (OSError, ValueError):
        pass
    return cfg


def save(gesture, action):
    cfg = load()
    cfg[gesture] = action
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    tmp = CONFIG + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=1)
    os.replace(tmp, CONFIG)
    return cfg


def _desktop(appid):
    """Name and icon of an app id from lomiri-app-launch-appids."""
    for path in (os.path.expanduser("~/.local/share/applications/%s.desktop" % appid),
                 "/usr/share/applications/%s.desktop" % appid):
        if not os.path.exists(path):
            continue
        cp = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            cp.read(path, encoding="utf-8")
            e = cp["Desktop Entry"]
        except Exception:
            continue
        icon = e.get("Icon", "")
        if icon and not icon.startswith("/"):
            # click apps may give a path relative to their install dir
            d = e.get("Path", "")
            if d and os.path.exists(os.path.join(d, icon)):
                icon = os.path.join(d, icon)
            else:
                icon = "image://theme/" + icon
        return e.get("Name", appid), icon
    return appid, ""


def apps():
    try:
        out = subprocess.run(["lomiri-app-launch-appids"], capture_output=True,
                             text=True, timeout=10).stdout.split()
    except Exception:
        out = []
    result = []
    for appid in out:
        parts = appid.split("_")
        key = "_".join(parts[:2]) if len(parts) == 3 else appid   # drop click version
        name, icon = _desktop(appid)
        if icon.startswith("/"):
            icon = "file://" + icon
        result.append({"id": "app:" + key, "name": name, "icon": icon})
    result.sort(key=lambda a: a["name"].lower())
    return result


def describe(action, applist):
    if action == "none":
        return "Nothing"
    if action == "torch":
        return "Torch"
    for a in applist:
        if a["id"] == action:
            return a["name"]
    return action[4:] if action.startswith("app:") else action
