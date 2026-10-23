# Build fixes needed on a current host

None of these are device problems; they are what it takes to build a 2019-2025
Qualcomm kernel tree on Ubuntu 26.04 with the halium 10 tooling, which assumes
the environment of 2019. Each cost a build cycle to find.

- **GNU Make must be 4.3 or older.** 4.4 rejects this kbuild's modbuiltin rules.
- **The tooling's clang is too old for the LineageOS tree.** halium 10 pulls
  clang 9 (r353983c), which fails the `-fstack-protector-strong` probe outright.
  clang 17 (`main-kernel-build-2023` / `r487747c`) works. Note the tooling skips
  re-cloning the clang repo if the directory exists but still deletes every
  revision but the requested one - switching clang branches leaves you with no
  compiler at all unless `workdir/downloads/linux-x86` is removed first.
- **A modern clang needs LLVM's own assembler**; the GCC 4.9 prebuilt's GNU as
  chokes on what clang emits (`junk at end of line`). Hence
  `deviceinfo_kernel_llvm_compile="true"`.
- **ROCm on the build host breaks `compile.h`.** `scripts/mkcompile_h` takes any
  line from `$CC -v` containing " version ", and clang prints `Found HIP
  installation: /usr/local, version ...`, which lands in the middle of a C string
  literal. Filter it.
- **clang 17/18 promotes warnings this tree trips to errors** - qcacld's
  `-Wfortify-source`, plus `-fmerge-constants` and a deprecated auto-var-init
  flag. Handled with `-Wno-` additions to KBUILD_CFLAGS.
- **dtc 1.4.4 from the kernel tree cannot parse the overlay device trees.** It
  fails on `&tlmm {` even with `/plugin/;` present. dtc 1.7.2 compiles them with
  warnings only, so `deviceinfo_kernel_use_dtc_ext="true"` with a modern dtc
  placed at `workdir/downloads/dtc_ext`.
- **The tooling builds every kernel tree into one shared `KERNEL_OBJ`.** Switching
  kernel source without deleting it silently mixes artefacts, and the build
  "succeeds" without compiling anything.
