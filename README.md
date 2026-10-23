# Ubuntu Touch for the Xiaomi Mi 9 (cepheus)

Ubuntu Touch 24.04 (24.04-2.x) on Halium 16, running on top of the vendor and
firmware of crDroid 16 (Android 16). Community port, not an official UBports
device yet.

> **Installing this erases Android and everything on the phone.** Read
> [Before you start](#before-you-start) completely before you run anything.

## What works

| Area | State |
|------|-------|
| Display, touch, brightness, rotation, notch-aware status bar | works |
| Calls, both SIM slots (dual SIM DSDS), call audio, speakerphone | works |
| Mobile data | works |
| SMS (incl. SMS over IMS) | not fully tested |
| Wi-Fi, Bluetooth | works |
| Speaker, earpiece, microphone | works |
| Cameras (photo and video, lens switching) and torch | works |
| Fingerprint (under-display) | works |
| NFC | works |
| Vibration, notification LED | works |
| Side ("AI") button - configurable in System Settings | works |
| IR blaster (TV remote app in `apps/cepheus-remote`) | works |
| Waydroid (Android apps) | works |
| MTP and ADB over USB | works |
| Battery, charging, suspend (about 0.5 %/h idle with the screen off) | works |
| GPS | not tested |
| Updates from System Settings | not available - see [Updating](#updating) |

Known issues:

- The audio HAL can crash (for example when unplugging USB); the microphone in
  calls is then silent until the next reboot.
- While the camera is open the journal gets a lot of harmless
  "SELinux is disabled, skipping restorecon" lines.

## Before you start

All of these are required. The installer cannot check most of them for you.

1. **The phone is a Xiaomi Mi 9, codename `cepheus`.** Not the Mi 9 SE
   (grus), Mi 9T (davinci) or Mi 9 Lite (pyxis). In fastboot mode
   `fastboot getvar product` must print `cepheus`.
2. **The bootloader is unlocked.** Use Xiaomi's official
   [Mi Unlock](https://en.miui.com/unlock/download_en.html) tool with your Mi
   account (bound in *Developer options > Mi Unlock status* while running
   MIUI). Xiaomi usually makes you wait 7 days or more before it allows the
   unlock. Unlocking wipes the phone.
3. **crDroid 16 (Android 16) for cepheus is installed and has booted at least
   once.** Ubuntu Touch uses its vendor, firmware and dynamic partition layout;
   **MIUI, stock firmware or any other ROM will not work.** Get it from
   [crdroid.net/cepheus](https://crdroid.net/cepheus) and install it exactly
   as its instructions say, including the firmware crDroid requires. Tested
   with `crDroidAndroid-16.0-20260912-cepheus-v12.12.zip`. Booting it once
   matters: Android sets the partitions up on the first boot.
4. **Battery at 50 % or more**, and a good USB cable. If fastboot keeps
   hanging, use a USB 2.0 port or a different computer - some USB 3
   controllers (AMD ones in particular) do not get along with this bootloader.
5. **Back up your data.** Internal storage is formatted.

### What you need on the computer

- Linux or macOS (on Windows, follow [Manual installation](#manual-installation)).
- `adb` and `fastboot` - Android
  [platform-tools](https://developer.android.com/tools/releases/platform-tools)
  (Debian/Ubuntu: `sudo apt install adb fastboot`).
- `curl` (or `wget`) and `sha256sum` (macOS: `brew install coreutils`).
- About 2 GB of free disk space.

## Installation (automatic)

```sh
git clone https://github.com/manutdsnake/ubuntu-touch-xiaomi-cepheus.git
cd ubuntu-touch-xiaomi-cepheus
./install.sh
```

The installer walks you through it:

1. downloads the latest [release](https://github.com/manutdsnake/ubuntu-touch-xiaomi-cepheus/releases)
   (about 1 GB) and checks the SHA-256 checksums;
2. asks you to put the phone into fastboot (power off, then hold
   **Volume Down + Power**), checks that it is a cepheus, and flashes the
   UBports recovery and the matching `dtbo`;
3. reboots into the recovery and formats userdata as ext4 (after asking);
4. copies the system files to the phone and installs them. The recovery
   removes crDroid's `product` and `system_ext` partitions and grows `system`
   to 4 GB for the Ubuntu Touch root filesystem; the vendor partition is kept;
5. reboots into Ubuntu Touch. The first boot takes a few minutes.

Options: `--files DIR` reuses files already downloaded, `--skip-recovery`
starts with the phone already in this release's recovery, `--keep-data`
does not format userdata (only for updates, see below).

If the phone shows the Mi logo or boots Android when it should be in
recovery, power it off and hold **Volume Up + Power** until the Ubuntu Touch
recovery appears; the installer waits for it.

## Manual installation

The same steps by hand, for Windows or if the installer cannot drive your
phone. Download every file of the latest
[release](https://github.com/manutdsnake/ubuntu-touch-xiaomi-cepheus/releases)
into one folder, open a terminal there, and check the files with
`sha256sum -c SHA256SUMS` (Windows: `certutil -hashfile <file> SHA256`).

1. Phone in fastboot (Volume Down + Power), then:
   ```sh
   fastboot flash recovery recovery.img
   fastboot flash dtbo dtbo.img
   fastboot reboot recovery
   ```
   (If `fastboot reboot recovery` is not supported: power off, then hold
   Volume Up + Power.)
2. In the Ubuntu Touch recovery choose **Factory reset** - this formats
   userdata as ext4. Then make sure `/cache` is there:
   ```sh
   adb shell 'mkdir -p /cache/recovery && ls /cache/recovery'
   ```
3. Copy the files and create the command file:
   ```sh
   adb push rootfs.tar.xz halium_halium_arm64.tar.xz device_cepheus.tar.xz version.tar.xz /cache/recovery/
   adb push image-master.tar.xz image-master.tar.xz.asc image-signing.tar.xz image-signing.tar.xz.asc /cache/recovery/
   adb shell 'cd /cache/recovery && for f in rootfs halium_halium_arm64 device_cepheus version; do touch $f.tar.xz.asc; done && touch allow-unsigned'
   adb push ubuntu_command /cache/recovery/
   ```
   `ubuntu_command` is in the release. The `allow-unsigned` file tells this
   port's recovery to accept files that are not signed by UBports (only for
   this one run).
4. Install and reboot:
   ```sh
   adb shell system-image-upgrader /cache/recovery/ubuntu_command
   adb reboot
   ```

## Updating

The port is not on the UBports update server yet, so System Settings will
not find updates. To install a newer release and **keep your data**:

```sh
git pull
./install.sh --keep-data
```

`--keep-data` replaces the system only; your apps, settings and files stay.

## Going back to Android

Ubuntu Touch changes the dynamic partitions (`product` and `system_ext` are
gone, `system` is bigger), so restore them with a full ROM install:

- **MIUI:** flash a cepheus fastboot ROM with Xiaomi's MiFlash tool
  ("clean all"). This restores every partition, including the stock recovery.
- **crDroid / LineageOS:** flash the ROM's own recovery and `dtbo` with
  fastboot, format data in it, and sideload the full ROM zip. Full ROM zips
  recreate the dynamic partitions.

## Building from source

The port uses the standard UBports
[halium-generic-adaptation-build-tools](https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools).
On Ubuntu 22.04 (or in an `ubuntu:22.04` container) with the usual kernel
build dependencies:

```sh
./build.sh -b workdir
```

This clones the kernel from
[manutdsnake/android_kernel_xiaomi_sm8150](https://github.com/manutdsnake/android_kernel_xiaomi_sm8150)
(branch `halium-16-cepheus`: LineageOS lineage-22.2 plus this port's
commits), and writes `boot.img`, `recovery.img`, `dtbo.img` and
`device_cepheus.tar.xz` to `out/`. `.gitlab-ci.yml` runs the same build in
UBports' GSI port pipeline.

Repository layout:

| Path | What it is |
|------|------------|
| `deviceinfo` | device description for the build tools |
| `overlay/system/` | files that go into the root filesystem (services, configs, fixed libraries) |
| `ramdisk/halium-boot-ramdisk.img` | boot ramdisk: halium's initramfs plus `initramfs-overlay/` (built by `tools/build-initramfs.sh`) |
| `ramdisk-recovery-overlay/` | recovery changes: retrofit dynamic partitions, local installs |
| `patches/` | notes and patches for components outside this repository |
| `port-debs/` | rebuilt packages whose files are in `overlay/` |
| `apps/` | small extra apps (IR remote, hardware test) |

### How the port differs from a usual Halium port

The Mi 9 has *retrofit* dynamic partitions: the Android "super" is spread over
the physical `system` and `vendor` partitions, with the metadata in `system`.
Halium's initramfs and the UBports recovery only know a real `super`
partition, so this port carries:

- a `parse-android-dynparts` that reads retrofit metadata and maps partitions
  that span several block devices (in the boot ramdisk);
- a `system-image-upgrader` that uses `system` as the metadata device, so the
  root filesystem can live in the logical `system` partition.

These are meant to go upstream to UBports/Halium.

## Credits

UBports and Halium for Ubuntu Touch, the build tools and the GSI; LineageOS and
crDroid for the kernel and the Android base the port runs on.
