#!/bin/bash
# finish.sh — установить ядро 6.17.13 + собрать/установить thomas-shirley (DKMS macbook12-audio/0.1).
# Запускать ТОЛЬКО после того, как `make -j4` завершился с BUILD_EXIT_CODE=0.
set -uo pipefail
SRC=/home/sogohimo/mb81-fix/src/linux-6.17.13
KV=6.17.13
cd "$SRC" || { echo "FATAL: нет дерева исходников"; exit 1; }

echo "=== [0] артефакты сборки на месте? ==="
ls -la arch/x86/boot/bzImage System.map || { echo "FATAL: bzImage нет (сборка не завершена?)"; exit 1; }

echo "=== [1] modules_install ==="
sudo make modules_install 2>&1 | tail -6

echo "=== [2] build-символическая ссылка -> полное дерево (нужна DKMS) ==="
sudo ln -sfn "$SRC" /lib/modules/$KV/build
ls -ld /lib/modules/$KV/build
if test -f /lib/modules/$KV/build/Makefile && test -f /lib/modules/$KV/build/Module.symvers; then
  echo "build-дерево ОК (Makefile + Module.symvers)"
else
  echo "WARN: build-дерево неполное"
fi

echo "=== [3] bzImage + System.map -> /boot ==="
sudo cp -f arch/x86/boot/bzImage /boot/vmlinuz-$KV
sudo cp -f System.map /boot/System.map-$KV
ls -la /boot/vmlinuz-$KV /boot/System.map-$KV

echo "=== [4] update-initramfs (initrd) ==="
sudo update-initramfs -c -k $KV 2>&1 | tail -6
ls -la /boot/initrd.img-$KV 2>/dev/null

echo "=== [5] update-grub (добавить в меню, 6.12 остаётся фоллбеком) ==="
sudo update-grub 2>&1 | tail -15

echo "=== [6] предпосев tarball драйвера в build-dir DKMS ==="
TARBALL=/home/sogohimo/mb81-fix/src/linux-6.17.13.tar.xz
DESTDIR=/var/lib/dkms/macbook12-audio/0.1/build/build
sudo mkdir -p "$DESTDIR"
sudo cp -f "$TARBALL" "$DESTDIR/linux-6.17.13.tar.xz"
ls -la "$DESTDIR/linux-6.17.13.tar.xz"

echo "=== [7] dkms build macbook12-audio/0.1 -k $KV ==="
sudo dkms build macbook12-audio/0.1 -k $KV 2>&1 | tail -60
echo "dkms build pipeline exit: ${PIPESTATUS[0]}"

echo "=== [8] dkms install macbook12-audio/0.1 -k $KV ==="
sudo dkms install macbook12-audio/0.1 -k $KV 2>&1 | tail -30

echo "=== [9] проверка: 3 модуля на месте + depmod ==="
sudo depmod -a
echo "--- updates/dkms (snd-hda-*.ko) ---"
find /lib/modules/$KV/updates/ \( -name "snd-hda-*.ko" -o -name "snd-hda-*.ko.zst" \) 2>/dev/null | sort
echo "--- dkms status ---"
sudo dkms status 2>&1

echo "=== [10] GRUB-меню: оба ядра видны? ==="
grep -iE "6\.17\.13|6\.12\.7[0-9]" /boot/grub/grub.cfg 2>/dev/null | grep -iE "menuentry|vmlinuz" | head -8

echo "=== FINISH_SCRIPT_DONE ==="
