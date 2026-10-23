# Packages rebuilt for this port

Their files are unpacked into `overlay/system/` (dpkg state is not touched: the
device tarball can only add or replace files). Rebuild on the device in a chroot of a copy of
`ubuntu.img` on userdata (`/userdata/build.img`, 12 GB, mounted at `/userdata/b`).

| Package | Source | Why |
|---|---|---|
| biometryd-bin, libbiometry2, qml-module-biometryd 0.4.0 | gitlab.com/ubports/development/core/biometryd `15ddc2c` (main, 2026-09-15) | The archive build dlopens `libbiometry_fp_api.so`, which no Android 16 container has. main talks to the fingerprint HAL through libgbinder (HIDL 2.1 / AIDL); here: `IBiometricsFingerprint@2.1/default`, UDFPS. |
| cameraplugin-aal 0.5.1 | gitlab.com/ubports/development/core/qtubuntu-camera `a167428` + `patches/qtubuntu-camera-audio-48k.patch` | Video recording: the plugin hard-coded 96 kHz audio, which AudioRecordHybris rejects, so every recording failed (`android_recorder_start() failed`). |

The libhybris q linker is not a package here: only `q.so` changes, see
`overlay/system/usr/lib/aarch64-linux-gnu/libhybris/linker/q.so` and
`patches/libhybris-q-release-static-tls-modules.patch` (ubports libhybris
24.04-2.x `61f88be`).

Version 0.4.0 sorts *below* the archive's `0.4.0+0~2026…`, so an `apt upgrade`
would put the old one back; hold them (`apt-mark hold`) or let the archive catch
up with upstream main.
