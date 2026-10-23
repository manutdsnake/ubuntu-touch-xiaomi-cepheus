#!/usr/bin/env python3
"""Pack a cepheus boot image the way this bootloader's stock images are packed.

Two things here are not what the halium tooling produces by default:

  * The kernel is wrapped in Qualcomm's UNCOMPRESSED_IMG container - a 16-byte
    magic and a little-endian u32 giving the size of the raw arm64 Image - with
    the device trees concatenated after it. Stock boot.img and recovery.img on
    this device are both built this way; a bare Image or a gzipped one is not.
  * There is no ramdisk section. The halium-boot initramfs is built into the
    kernel through CONFIG_INITRAMFS_SOURCE instead, so the image the bootloader
    sees carries a kernel and nothing else, exactly like stock boot.img.

Usage: pack-bootimg.py --kernel Image --dtb merged.dtb --partition boot|recovery -o out.img
"""
import argparse
import os
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MKBOOTIMG = os.path.join(HERE, "workdir/downloads/android_system_tools_mkbootimg/mkbootimg.py")
AVBTOOL = os.path.join(HERE, "workdir/downloads/avb/avbtool.py")
SIZES = {"boot": 134217728, "recovery": 67108864}


def deviceinfo():
    info = {}
    for line in open(os.path.join(HERE, "deviceinfo")):
        line = line.strip()
        if line.startswith("deviceinfo_") and "=" in line:
            k, v = line.split("=", 1)
            info[k] = v.strip().strip('"')
    return info


def wrap_uncompressed(image, dtbs):
    """UNCOMPRESSED_IMG header + raw Image + appended device trees."""
    out = b"UNCOMPRESSED_IMG" + struct.pack("<I", len(image)) + image
    for d in dtbs:
        out += d
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kernel", required=True)
    ap.add_argument("--dtb", action="append", default=[])
    ap.add_argument("--partition", default="boot", choices=sorted(SIZES))
    ap.add_argument("--cmdline")
    ap.add_argument("--header-version", default="1", help="boot header version; the stock recovery on cepheus is v0")
    ap.add_argument("--os-version"); ap.add_argument("--os-patch-level")
    ap.add_argument("--ramdisk", help="only for comparing against a stock-shaped image")
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    info = deviceinfo()
    image = open(args.kernel, "rb").read()
    dtbs = [open(d, "rb").read() for d in args.dtb]
    payload = wrap_uncompressed(image, dtbs)

    stage = args.output + ".kernel"
    open(stage, "wb").write(payload)

    cmd = [
        sys.executable, MKBOOTIMG,
        "--kernel", stage,
        "--header_version", args.header_version,
        "--pagesize", info["deviceinfo_flash_pagesize"],
        "--base", info["deviceinfo_flash_offset_base"],
        "--kernel_offset", info["deviceinfo_flash_offset_kernel"],
        "--ramdisk_offset", info["deviceinfo_flash_offset_ramdisk"],
        "--second_offset", info["deviceinfo_flash_offset_second"],
        "--tags_offset", info["deviceinfo_flash_offset_tags"],
        "--os_version", args.os_version or info["deviceinfo_bootimg_os_version"],
        "--os_patch_level", args.os_patch_level or info["deviceinfo_bootimg_os_patch_level"],
        "--cmdline", args.cmdline or info["deviceinfo_kernel_cmdline"],
        "-o", args.output,
    ]
    if args.ramdisk:
        cmd += ["--ramdisk", args.ramdisk]
    subprocess.run(cmd, check=True)
    os.unlink(stage)

    # The bootloader rejects an image with no AVB footer within seconds, even
    # unlocked. It does not check the signature, so an unsigned footer is enough.
    subprocess.run([
        sys.executable, AVBTOOL, "add_hash_footer",
        "--image", args.output,
        "--partition_name", args.partition,
        "--partition_size", str(SIZES[args.partition]),
    ], check=True)

    print(f"{args.output}: kernel {len(image)} + {len(dtbs)} dtb "
          f"({sum(len(d) for d in dtbs)}) -> {os.path.getsize(args.output)} bytes, "
          f"{args.partition} footer")


if __name__ == "__main__":
    main()
