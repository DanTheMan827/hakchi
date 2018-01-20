#!/bin/sh
checkFile(){
  [ -f "$1" ] && return 0
  echo "Not Found: $1"
  return 1
}

scriptPath="$(dirname "$0")"
cd "$scriptPath"
scriptPath="$(pwd)"
sd="$scriptPath/sd"
sdTemp="$sd/temp"
sdImg="$sd.img"
sdFs="$sdTemp/data.fat32"
squashTemp="$sdTemp/squash"
updateTemp="$sdTemp/update"
squashFile="$sdTemp/squash.hsqs"
fsRoot="$squashTemp/fsroot"

checkFile "$scriptPath/dump/kernel.img" || exit 1
checkFile "$sd/boot0.bin" || exit 2
checkFile "$sd/uboot.bin" || exit 3
checkFile "$sd/squash/bin/sntool.static" || exit 3

rm -r "kernel" "kernel.img" "$sd/out" "sd.img.xz"
export PATH="$PATH:$scriptPath/bin:$scriptPath/build"
extractimg || exit 4
rm "kernel/initramfs/key-file"
makeimg ./kernel notx || exit 5

echo $sdTemp
[ -d "$sdTemp" ] && (rm -r "$sdTemp" || exit 6)
mkdir -p "$sdTemp" "$updateTemp" "$squashTemp" "$fsRoot" || exit 7
dd if=/dev/zero "of=$sdImg" bs=1M count=128 || exit 8
dd if=/dev/zero "of=$sdFs" bs=1M count=96 || exit 9

sfdisk "$sdImg" <<EOT
32M,,06
EOT

[ "$?" != "0" ] && exit 10

mkfs.vfat -F 16 -s 16 "$sdFs" || exit 11
mkdir -p "$fsRoot/hakchi/rootfs/bin" || exit 12
rsync -ac "$scriptPath/mod/hakchi/rootfs/" "$fsRoot/hakchi/rootfs" || exit 13
rsync -ac "$scriptPath/mod/bin/" "$fsRoot/hakchi/rootfs/bin" || exit 14

if [ -d "mod/hakchi/transfer" ]; then
  mkdir -p "$fsRoot/hakchi/transfer" || exit 15
  rsync -ac "mod/hakchi/transfer/" "$fsRoot/hakchi/transfer/" || exit 16
fi

rsync -ac --links "$sd/fs/" "$fsRoot/" || exit 17
chmod -R a+rw "$fsRoot" || exit 18
chmod -R a+x "$fsRoot/hakchi/rootfs/bin" "$fsRoot/hakchi/rootfs/etc/init.d" || exit 19
mkdir -p "$squashTemp/hakchi/" || exit 20
find "$fsRoot"

cp "3rdparty/util-linux-2.31.1/sfdisk.static" "$squashTemp/sfdisk" || exit 21
cp "3rdparty/e2fsprogs/misc/mke2fs.static" "$squashTemp/mke2fs" || exit 22
cp "mod/bin/rsync" "$squashTemp/rsync" || exit 23
chmod a+x "$squashTemp/sfdisk" "$squashTemp/mke2fs" "$squashTemp/rsync" || exit 24

rsync -ac --links "$sd/squash/" "$squashTemp/" || exit 25
mksquashfs "$squashTemp" "$squashFile" -all-root || exit 26

rsync -ac "$sd/update/" "$updateTemp/" || exit 27

echo "hakchi" | dd "of=$sdImg" conv=notrunc || exit 28
dd "if=$sdFs" "of=$sdImg" bs=1M seek=32 conv=notrunc || exit 29
dd "if=$sd/boot0.bin" "of=$sdImg" bs=1K seek=8 conv=notrunc || exit 30
dd "if=$sd/uboot.bin" "of=$sdImg" bs=1K seek=19096 conv=notrunc || exit 31
dd "if=$scriptPath/kernel.img" "of=$sdImg" bs=1K seek=20480 conv=notrunc || exit 32
dd "if=$squashFile" "of=$sdImg" bs=1K seek=40 conv=notrunc || exit 33
dd "if=$sdFs" "of=$sdImg" bs=1M seek=32 conv=notrunc || exit 34

cp "$sd/boot0.bin" "$sd/uboot.bin" "$scriptPath/kernel.img" "$squashFile" "$updateTemp/" || exit 35
mkdir -p "$sd/out/" || exit 36
mv "$sdImg" "$sd/out/sd.img" || exit 37
tar -czvf "$sd/out/update.hmod" -C "$updateTemp" . || exit 38
rm -r "kernel" "kernel.img" || exit 39
rm -r "$sdTemp" || exit 40
