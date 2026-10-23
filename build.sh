#!/bin/bash
set -xe
umask 022

# The device tarball keeps the checkout's file modes; a umask 002 checkout
# would make /etc, /usr/... group-writable on the phone.
chmod -R go-w overlay

# deviceinfo_kernel_use_dtc_ext: the build tools would fetch Android's
# prebuilt dtc 1.4.2, which encodes the DTBs and the dtbo differently from
# the dtc 1.7.2 this port was built and tested with (the bootloader is picky
# about device trees, and the OTA flashes dtbo.img). Build that dtc here and
# put it where the tools look first.
BUILD_DIR=workdir
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    [ "${args[i]}" = "-b" ] && BUILD_DIR="${args[i+1]}"
done
if [ ! -x "$BUILD_DIR/downloads/dtc_ext" ]; then
    mkdir -p "$BUILD_DIR/downloads"
    rm -rf "$BUILD_DIR/dtc-src"
    git -c advice.detachedHead=false clone --depth 1 -b v1.7.2 https://git.kernel.org/pub/scm/utils/dtc/dtc.git "$BUILD_DIR/dtc-src"
    make -C "$BUILD_DIR/dtc-src" NO_PYTHON=1 NO_YAML=1 NO_VALGRIND=1 dtc
    cp "$BUILD_DIR/dtc-src/dtc" "$BUILD_DIR/downloads/dtc_ext"
fi

[ -d build ] || git clone https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools -b main build
./build/build.sh "$@"
