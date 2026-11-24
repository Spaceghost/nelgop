#!/bin/sh
set -eu
: "${NELUA:?Set NELUA to the pinned compiler executable}"
: "${NELINKER:?Set NELINKER to a build with AArch64 EFI support}"
: "${CLANG:=clang}"
: "${QEMU:=qemu-system-aarch64}"
: "${EDK2_CODE:=/usr/share/edk2/aarch64/QEMU_EFI-pflash.raw}"
: "${EDK2_VARS:=/usr/share/edk2/aarch64/vars-template-pflash.raw}"
src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT HUP INT TERM

"$NELUA" --cache-dir "$d/cache" -L "$src/lib" --cc "$CLANG" --target aarch64-none-elf \
  --cflags=-ffreestanding --print-code "$src/test/capture_aarch64.nelua" > "$d/capture.c"
"$CLANG" --target=aarch64-none-elf -O2 -ffreestanding -fno-builtin -fno-stack-protector \
  -fno-pic -fno-unwind-tables -fno-asynchronous-unwind-tables \
  -c "$d/capture.c" -o "$d/capture.o"
"$NELINKER" --aarch64 --efi-app -o "$d/BOOTAA64.EFI" "$d/capture.o"

truncate -s 66M "$d/disk.img"
printf 'label: gpt\nstart=2048, size=131072, type=U\n' | sfdisk --quiet "$d/disk.img"
esp="$d/disk.img@@1048576"
mformat -i "$esp" -F -T 131072 -H 2048 ::
mmd -i "$esp" ::EFI ::EFI/BOOT
mcopy -i "$esp" "$d/BOOTAA64.EFI" ::EFI/BOOT/BOOTAA64.EFI
cp "$EDK2_VARS" "$d/vars.raw"

python3 "$src/test/check_capture.py" "${CAPTURE:-}" \
  "$QEMU" -nodefaults -machine virt -accel tcg -cpu cortex-a57 -m 1024 -no-reboot \
  -display none -monitor none -serial stdio \
  -drive "if=pflash,format=raw,file=$EDK2_CODE,readonly=on" \
  -drive "if=pflash,format=raw,file=$d/vars.raw" \
  -drive "if=none,format=raw,file=$d/disk.img,id=esp" \
  -device virtio-blk-pci,drive=esp,bootindex=1 -device virtio-gpu-pci
