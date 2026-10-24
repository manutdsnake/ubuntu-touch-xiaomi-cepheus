# Device settings for install.sh - Xiaomi Mi 9 (cepheus).

NAME="Xiaomi Mi 9"
CODENAME="cepheus"
REPO="manutdsnake/ubuntu-touch-xiaomi-cepheus"
# /proc/device-tree/model in recovery: "CEPHEUS"
DT_MODEL_MATCH="cepheus"

# Flashed with fastboot to get into the UBports recovery. The recovery and
# this port's kernel need this port's dtbo.
RECOVERY_IMAGES=(recovery.img dtbo.img)

# The Android base the port runs on, written from recovery as
# "file partition offset" (offset in 4096-byte blocks):
# - the LP metadata of the retrofit super (system 4 GiB, vendor, odm spread
#   over the physical system and vendor partitions) at the start of the
#   physical system partition;
# - vendor and odm of crDroid 16 (crDroidAndroid-16.0-20260912-cepheus-v12.12)
#   where that metadata places them (vendor: system @ sector 3059840,
#   odm: system @ sector 7029520);
# - crDroid's vbmeta.
BASE=(
    "lp-metadata.img system 0"
    "vendor.img system 382480"
    "odm.img system 878690"
    "vbmeta.img vbmeta 0"
)

# Firmware: MIUI V12.0.5.0.QFAEUXM (EEA, Android 10) - the firmware this port
# was built and tested on - from Xiaomi's recovery ROM (its firmware-update/
# files are identical to the fastboot ROM's). Checked partition by partition;
# only downloaded and flashed when something differs. Partitions (with the
# *bak copies) as Xiaomi's flash_all.sh writes them.
FIRMWARE_NAME="MIUI V12.0.5.0.QFAEUXM (EEA) firmware"
FIRMWARE_URL="https://bn.d.miui.com/V12.0.5.0.QFAEUXM/miui_CEPHEUSEEAGlobal_V12.0.5.0.QFAEUXM_8c911c47a4_10.0.zip"
FIRMWARE_SHA256="149e1687e324c54d7b164ac44e3ae52c587d03c1bf38edcc0a02e4d5c5d2f7c5"
FIRMWARE_ARCHIVE="zip"
FIRMWARE_SIZE="2.5 GB"
#   "partition member-in-archive size sha256"
FIRMWARE=(
    "xbl firmware-update/xbl.elf 4107296 369efe4a7a9c95f3726ee5d3c265a4e23464380b4c282f03dafc6a212137778f"
    "xblbak firmware-update/xbl.elf 4107296 369efe4a7a9c95f3726ee5d3c265a4e23464380b4c282f03dafc6a212137778f"
    "xbl_config firmware-update/xbl_config.elf 123536 638ef2f0f6e556edef8c866e9506845d21ee6dcf8828e8c45ac24e1bb925e698"
    "xbl_configbak firmware-update/xbl_config.elf 123536 638ef2f0f6e556edef8c866e9506845d21ee6dcf8828e8c45ac24e1bb925e698"
    "abl firmware-update/abl.elf 208896 b6bc845e586d0fbe2314b4038fb5602fdf4aaa6b15867ed6fe24ae870a9e966e"
    "ablbak firmware-update/abl.elf 208896 b6bc845e586d0fbe2314b4038fb5602fdf4aaa6b15867ed6fe24ae870a9e966e"
    "tz firmware-update/tz.mbn 3169690 18a23034fcfc31084fb05456193839fea88450689caa80013c927b79c4aae380"
    "tzbak firmware-update/tz.mbn 3169690 18a23034fcfc31084fb05456193839fea88450689caa80013c927b79c4aae380"
    "hyp firmware-update/hyp.mbn 488328 3f41d5d84bb1fe37707db600dc02ad337a54c8a96640ad8807f3a4df067fa8f0"
    "hypbak firmware-update/hyp.mbn 488328 3f41d5d84bb1fe37707db600dc02ad337a54c8a96640ad8807f3a4df067fa8f0"
    "devcfg firmware-update/devcfg.mbn 54284 9572bc3c4e44a1816128d8a05c8a1148af4938a3979d863149d32426f0048b17"
    "devcfgbak firmware-update/devcfg.mbn 54284 9572bc3c4e44a1816128d8a05c8a1148af4938a3979d863149d32426f0048b17"
    "storsec firmware-update/storsec.mbn 20565 6f58e13695e8c850cc6e5bffadda7a6cd911179a1e32ae8f16b56b7377652431"
    "bluetooth firmware-update/BTFM.bin 847872 bcd9baf6219f69df446436b52dc314eac57f9caff9d2a054da89d392e485e929"
    "cmnlib firmware-update/cmnlib.mbn 392502 9b419f59236ca45246b68d9162d555c09edde3479f8fd96ed6912b421de3374a"
    "cmnlibbak firmware-update/cmnlib.mbn 392502 9b419f59236ca45246b68d9162d555c09edde3479f8fd96ed6912b421de3374a"
    "cmnlib64 firmware-update/cmnlib64.mbn 511386 9a6b83c7cb947595603d0dba328c26b28df3be367b0b431ef0af91fdd6d37f8a"
    "cmnlib64bak firmware-update/cmnlib64.mbn 511386 9a6b83c7cb947595603d0dba328c26b28df3be367b0b431ef0af91fdd6d37f8a"
    "modem firmware-update/NON-HLOS.bin 180187136 42f98952e8e85fd7d3496d41cc8a45300aed563cb89a406ed272904c6c60f487"
    "dsp firmware-update/dspso.bin 67108864 810f73aa0ab15fcf942f8fd25036b20b834a35dcff584b3134d4bafdcf6e85f3"
    "keymaster firmware-update/km4.mbn 250770 f391e750bd1e6116c80a483c90287d2fe2737dd563cbc19440886bc377f41029"
    "keymasterbak firmware-update/km4.mbn 250770 f391e750bd1e6116c80a483c90287d2fe2737dd563cbc19440886bc377f41029"
    "logo firmware-update/logo.img 25296896 be3d77d1d356d69a2004c6f409ef6d8dbb42196c4ff2e6957b0f1aa32a595f87"
    "aop firmware-update/aop.mbn 200680 907badfc5616fa1be02a35806784c8d2cc44f96b55db8537349a7e6aed94a1a1"
    "aopbak firmware-update/aop.mbn 200680 907badfc5616fa1be02a35806784c8d2cc44f96b55db8537349a7e6aed94a1a1"
    "qupfw firmware-update/qupv3fw.elf 70730 5514c9bac4200a52fbbbe4d0ea18de6131b4ed63b8e57296f16487cc487692e0"
    "qupfwbak firmware-update/qupv3fw.elf 70730 5514c9bac4200a52fbbbe4d0ea18de6131b4ed63b8e57296f16487cc487692e0"
    "imagefv firmware-update/imagefv.elf 28672 e63146186ce7a7bcfcbdd939ad5b3bc53901f491684960fc6274d22f182b9d35"
    "uefisecapp firmware-update/uefi_sec.mbn 125583 ef44f4b0e3e93ba429fe689928cc3bec72b9d482c6e2f36b77f05ec8ee1cb9e3"
    "uefisecappbak firmware-update/uefi_sec.mbn 125583 ef44f4b0e3e93ba429fe689928cc3bec72b9d482c6e2f36b77f05ec8ee1cb9e3"
)
