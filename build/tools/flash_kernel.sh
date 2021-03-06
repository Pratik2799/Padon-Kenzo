#!/sbin/sh
 #
 # Copyright � 2017, Umang Leekha "umang96" <umangleekha3@gmail.com> 
 #
 # Live ramdisk patching script
 #
 # This software is licensed under the terms of the GNU General Public
 # License version 2, as published by the Free Software Foundation, and
 # may be copied, distributed, and modified under those terms.
 #
 # This program is distributed in the hope that it will be useful,
 # but WITHOUT ANY WARRANTY; without even the implied warranty of
 # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 # GNU General Public License for more details.
 #
 # Please maintain this if you use this script or any part of it
 #
selinx=$(cat /tmp/aroma/sel.prop | cut -d '=' -f2)
qc=$(cat /tmp/aroma/crate.prop | cut -d '=' -f2)
pt=$(cat /tmp/aroma/pt.prop | cut -d '=' -f2)
therm=$(cat /tmp/aroma/thermal.prop | cut -d '=' -f2)
net=$(cat /tmp/aroma/netmode.prop | cut -d '=' -f2)
jk=$(cat /tmp/aroma/jack.prop | cut -d '=' -f2)
ftfw=$(cat /tmp/aroma/ftfw.prop | cut -d '=' -f2)
nos1=`cat /system/build.prop | grep ro.product.name=`
nos2=${nos1:16:8}
if [ $nos2 == "nitrogen" ]; then
echo "NitrogenOS detected, forcing permissive"
selinx=2
fi
zim=/tmp/Image1
dim="/tmp/dt"$pt$qc".img"
cmd="androidboot.hardware=qcom ehci-hcd.park=3 androidboot.bootdevice=7824900.sdhci lpm_levels.sleep_disabled=1 ramoops_memreserve=4M"
if [ $selinx -eq 1 ]; then
cmd=$cmd" androidboot.selinux=enforcing"
elif [ $selinx -eq 2 ]; then
cmd=$cmd" androidboot.selinux=permissive"
fi
if [ $net -eq 1 ]; then
cmd=$cmd" android.gdxnetlink=old"
elif [ $net -eq 2 ]; then
cmd=$cmd" android.gdxnetlink=los"
fi
if [ $jk -eq 2 ]; then
cmd=$cmd" android.audiojackmode=stock"
fi
if [ $ftfw -eq 1 ]; then
cmd=$cmd" androidboot.ft5346.flash=force"
fi
if [ $therm -eq 1 ]; then
echo "Using saxy thermals + pubg config"
cp -rf /tmp/saxy-thermals/* /system/vendor/etc/
chmod 0644 /system/vendor/etc/thermal-engine.conf
fi
cp /tmp/radon.sh /system/etc/radon.sh
chmod 644 /system/etc/radon.sh
cp -f /tmp/cpio /sbin/cpio
cd /tmp/
/sbin/busybox dd if=/dev/block/bootdevice/by-name/boot of=./boot.img
./unpackbootimg -i /tmp/boot.img
mkdir /tmp/ramdisk
cp /tmp/boot.img-ramdisk.gz /tmp/ramdisk/
cd /tmp/ramdisk/
gunzip -c /tmp/ramdisk/boot.img-ramdisk.gz | /tmp/cpio -i
rm /tmp/ramdisk/boot.img-ramdisk.gz
rm /tmp/boot.img-ramdisk.gz
cp /tmp/init.radon.rc /tmp/ramdisk/
# ADD SPECTRUM SUPPORT
cp /tmp/init.spectrum.rc /tmp/ramdisk/
cp /tmp/init.spectrum.sh /tmp/ramdisk/
chmod 0750 /tmp/ramdisk/init.spectrum.rc
if [ $(grep -c "import /init.spectrum.rc" /tmp/ramdisk/init.rc) == 0 ]; then
   sed -i "/import \/init\.\${ro.hardware}\.rc/aimport /init.spectrum.rc" /tmp/ramdisk/init.rc
fi
# COMPATIBILITY FIXES START
if [ -f /tmp/ramdisk/fstab.qcom ];
then
if ([ "`grep "context=u:object_r:firmware_file:s0" /tmp/ramdisk/fstab.qcom`" ]);
then
rm /tmp/ramdisk/fstab.qcom
cp /tmp/fstab.qcom /tmp/ramdisk/fstab.qcom
else
rm /tmp/ramdisk/fstab.qcom
cp /tmp/fstab.qcom.no-context /tmp/ramdisk/fstab.qcom
fi
chmod 640 /tmp/ramdisk/fstab.qcom
fi
if [ -f /tmp/ramdisk/init.darkness.rc ]; then
rm /tmp/ramdisk/init.darkness.rc
fi
chmod 0750 /tmp/ramdisk/init.radon.rc
if [ $(grep -c "import /init.radon.rc" /tmp/ramdisk/init.rc) == 0 ]; then
   sed -i "/import \/init\.\${ro.hardware}\.rc/aimport /init.radon.rc" /tmp/ramdisk/init.rc
fi
find . | cpio -o -H newc | gzip > /tmp/boot.img-ramdisk.gz
rm -r /tmp/ramdisk
cd /tmp/
./mkbootimg --kernel $zim --ramdisk /tmp/boot.img-ramdisk.gz --cmdline "$cmd"  --base 0x80000000 --pagesize 2048 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --dt $dim -o /tmp/newboot.img
/sbin/busybox dd if=/tmp/newboot.img of=/dev/block/bootdevice/by-name/boot
