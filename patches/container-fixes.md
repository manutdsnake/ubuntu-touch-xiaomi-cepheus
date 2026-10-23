# What the Android container needed on cepheus

All four of these are host-side: nothing in the Halium GSI or the UBports rootfs
had to change. They are applied at runtime today (edits inside `ubuntu.img`) and
still need to be folded into the overlay properly.

## 1. `/dev/binder` does not exist - `CONFIG_ANDROID_BINDERFS`

This kernel has `CONFIG_ANDROID_BINDERFS=y`, so binder, hwbinder and vndbinder
are inodes in a binderfs mount rather than misc devices. There is no uevent for
them, so Android 10's ueventd cannot create them inside the container's private
`/dev` tmpfs, and init aborts:

    init: processing action (InitBinder) from (<Builtin Action>:0)
    android::ProcessState::ProcessState(char const*)+400
    __android_log_assert  ->  abort

Fix: symlink them from the host's binderfs in `lxc.hook.mount`
(`/var/lib/lxc/android/mount.sh`):

    for b in binder hwbinder vndbinder; do
        ln -sf /dev/binderfs/$b "${LXC_ROOTFS_MOUNT}/dev/$b"
    done

Turning `CONFIG_ANDROID_BINDERFS` off and letting the driver register the three
misc devices would work too, but Ubuntu Touch's own `dev-binderfs.mount` wants
binderfs for Anbox.

## 2. binderfs nodes are 0600 root:root

`servicemanager` and `hwservicemanager` run as `system`, so with the default
binderfs permissions they die immediately - `exited with status 255` and
`received signal 6`, taking every HIDL HAL with them. `chmod 0666` on the three
nodes before the container starts.

## 3. The property area cannot be re-created

`property_init()` creates each file under `/dev/__properties__` with `O_EXCL`, so
the container starts exactly once per boot. Every restart after that aborts with
`Failed to initialize property area`, which looks like a fatal error but is only
a leftover. `rm -rf /dev/__properties__/*` in `pre-start.sh` - not in
`pre-start.d/`, because `run-parts` there is guarded by `[ -w $LXC_ROOTFS_PATH ]`
and the container rootfs is read-only.

## 4. libhybris cannot find the Adreno EGL sub-driver

    dlopen failed: library "eglSubDriverAndroid.so" not found
    must have at least EGL 1.4

The hybris linker searches `/system/lib64:/odm/lib64:/vendor/lib64` and reads
`/system/etc/ld.config.txt`, *not* the `ld.config.29.txt` the Halium GSI ships,
so patching that file does nothing. Two things fix it, and both are in place:
`HYBRIS_LD_LIBRARY_PATH` with `/vendor/${LIB}/egl` appended (systemd
`DefaultEnvironment`), and a copy of `eglSubDriverAndroid.so` in the GSI's
`/system/lib64`.

## Where it stands

With 1-3 applied the container starts services for the first time - logd,
vndservicemanager, vold, the Qualcomm daemons - and with 4 applied the EGL driver
loads. The device then reboots in a loop a few seconds in, which is new: it only
started once the vendor HALs began running against the **stock** device tree.
That is the thread to pull next, and it leads back to the device tree the
bootloader will not accept.

## On the crDroid 16 base

`/data` must be a plain ext4. crDroid's recovery formats it with casefold and
other post-2017 features, and halium-boot's initramfs carries e2fsprogs 1.43.4
from 2017: `e2fsck` refuses the filesystem outright, but `resize_userdata_if_needed`
runs `resize2fs` on it anyway and destroys the journal, so the next boot cannot
mount `/data` at all ("JBD2: recovery failed"). Reformat from the rescue shell
with the initramfs' own `mke2fs -t ext4 -F` and it stays healthy.
`CONFIG_UNICODE` is still worth having so the kernel can mount a casefold
filesystem when it meets one.
