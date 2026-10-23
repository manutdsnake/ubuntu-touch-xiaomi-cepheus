#!/usr/bin/env python3
"""Flash a MIUI fastboot package on a bootloader that hangs mid-session.

cepheus' bootloader accepts a handful of fastboot commands and then stops
answering: the client blocks in an uninterruptible USB ioctl and Xiaomi's own
flash_all.sh dies on the spot. The device itself is fine - resetting the USB port
from the host frees the client, and after `fastboot reboot bootloader` flashing
continues from where it stopped.

So instead of one long session, run every command in its own short-lived one and
treat a hang as expected: reset, reboot the bootloader, retry.

Usage: PORT=1-11 SUDO_PASS=... robust-fastboot-flash.py <package-dir> [--from N]
"""
import os
import re
import shutil
import subprocess
import sys
import time

FASTBOOT = shutil.which("fastboot") or "fastboot"
PORT = os.environ.get("PORT", "1-11")
SUDO_PASS = os.environ.get("SUDO_PASS", "")
TIMEOUT = int(os.environ.get("TIMEOUT", "300"))
RETRIES = 4


def usb_reset():
    """Unbind and rebind the port, which releases a client stuck in the ioctl."""
    path = f"/sys/bus/usb/devices/{PORT}/authorized"
    script = f"echo 0 > {path}; sleep 2; echo 1 > {path}"
    subprocess.run(
        ["sudo", "-S", "sh", "-c", script],
        input=SUDO_PASS + "\n", text=True,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    time.sleep(5)


def wait_for_device(limit=60):
    for _ in range(limit):
        out = subprocess.run([FASTBOOT, "devices"], capture_output=True, text=True, timeout=20)
        if out.stdout.strip():
            return True
        time.sleep(2)
    return False


def reboot_bootloader():
    subprocess.run([FASTBOOT, "reboot", "bootloader"], capture_output=True, timeout=60)
    time.sleep(8)
    return wait_for_device()


def parse(script_path):
    """Pull the fastboot commands out of flash_all.sh, in order."""
    steps = []
    pattern = re.compile(r"^fastboot \$\* (flash (\S+) `dirname \$0`/images/(\S+)|erase (\S+)|reboot)\s*$")
    for line in open(script_path):
        m = pattern.match(line.strip())
        if not m:
            continue
        if m.group(2):
            steps.append(("flash", m.group(2), m.group(3)))
        elif m.group(4):
            steps.append(("erase", m.group(4), None))
        else:
            steps.append(("reboot", None, None))
    return steps


def run_step(kind, target, image, pkg):
    if kind == "flash":
        cmd = [FASTBOOT, "flash", target, os.path.join(pkg, "images", image)]
    elif kind == "erase":
        cmd = [FASTBOOT, "erase", target]
    else:
        return True, "skipped final reboot"
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
        return r.returncode == 0, (r.stdout + r.stderr).strip().splitlines()[-1:] or [""]
    except subprocess.TimeoutExpired:
        return False, ["HANG"]


def main():
    pkg = sys.argv[1]
    start = 0
    if "--from" in sys.argv:
        start = int(sys.argv[sys.argv.index("--from") + 1])
    steps = parse(os.path.join(pkg, "flash_all.sh"))
    print(f"{len(steps)} steps, starting at {start}", flush=True)

    for i, (kind, target, image) in enumerate(steps):
        if i < start or kind == "reboot":
            continue
        label = f"[{i:2d}] {kind} {target}"
        for attempt in range(1, RETRIES + 1):
            ok, msg = run_step(kind, target, image, pkg)
            if ok:
                print(f"{label:34} OK", flush=True)
                break
            print(f"{label:34} FAIL ({msg[-1] if msg else '?'}) - recovering, try {attempt}", flush=True)
            usb_reset()
            if not reboot_bootloader():
                print(f"{label:34} device did not come back", flush=True)
                return 1
        else:
            print(f"{label:34} GIVING UP", flush=True)
            return 1
    print("all steps done", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
