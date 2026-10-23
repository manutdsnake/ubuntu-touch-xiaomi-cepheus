# crDroid's retrofit super partition

cepheus has no `super` partition. crDroid retrofits one across the physical
`system` and `vendor` partitions, and `/vendor` ends up living *inside* physical
`system`. halium-boot cannot cope: it only looks for
`/dev/disk/by-partlabel/super`, and its `parse-android-dynparts` refuses anything
else outright - "This utility does not yet support multiple block devices".

Without `/vendor` the container dies immediately:

    init: Failed to read /vendor/etc/selinux/plat_sepolicy_vers.txt
    init: Could not read vendor SELinux version
    init: InitFatalReboot: signal 6   (SelinuxGetVendorAndroidVersion)

`tools/lp-tables.py` reads the super metadata straight off the device and prints
the device-mapper tables; `initramfs-overlay/scripts/cepheus-dynparts` applies
them with `dmsetup` from inside the initramfs, before halium-boot's own super
handling. The tables are fixed until the ROM is reflashed - regenerate them after
any crDroid update, because a stale table silently maps the wrong bytes.

The initramfs is patched by **appending** a second cpio archive to the halium one
rather than unpacking and repacking it: unpacking as a normal user loses
ownership and special files, and the kernel simply lets later entries win.

## Where it stands

With this in place the phone runs for six minutes at a time instead of dying,
`/vendor` mounts, and Android init gets past the SELinux version check. The
display still does not come up: Mir's android platform probes at
`Support priority: 0` and gives "Failed to find platform for current system",
which means it cannot reach the graphics HALs. That is the next thread.

Note that "no USB" is not a failure signal on this port - the phone has run for
283 and 346 seconds with nothing at all on the cable. Read
`/userdata/kmsg.log`, which `halium-kmsg-log` writes from early boot and which
survives a reset, or the journal under `system-data/var/log`.

## Why the mounting lives in the initramfs

A systemd unit is the obvious place and it does not work. Ordered
`Before=lxc-android-config.service` and pulled in by `sysinit.target`, it forms a
cycle, and systemd resolves that by quietly dropping the job:

    lxc-android-config.service: Found ordering cycle on sysinit.target/stop
    lxc-android-config.service: Found dependency on halium-android-partitions.service/stop
    Job sysinit.target/stop deleted to break ordering cycle

The unit never runs and nothing says so unless you read the journal. Moving both
halves into halium-boot - `cepheus-dynparts` for the device-mapper tables, and
`cepheus-mounts` right after the Android system is moved into `${rootmnt}/android`
- puts the vendor tree in place before anything in userspace starts, which is
what Android init expects anyway.
