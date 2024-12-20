#!/bin/sh

## Umount image
_umount_img() {
    local _loopdevice
    _loopdevice="$(losetup -ln -O name -j "${output_target}/${image_name}.img")"
    if mountpoint -q -- "${worktmp}/imgp1"; then
        umount -l "${worktmp}/imgp1"
    fi
    if mountpoint -q -- "${worktmp}/imgp2"; then
        umount -l "${worktmp}/imgp2"
    fi
    if [[ -n "${_loopdevice}" ]]; then
        losetup -d "${_loopdevice}"
    fi
}

# Create Image
_create_img() {
    trap _umount_img EXIT
    local _espsize _loopdevice

    rm -f -- "${output_target}/${image_name}.img"
    printf '\e[1;34m-->\e[0m\e[1m Creating GPT disk image\e[0m\n'
    
    _espsize=600
    [[ -z ${_rootlabel} ]] && _rootlabel=manjaro_root
    [[ -z ${_esplabel} ]] && _esplabel=manjaro_esp

    # IMG size = 20 GiB
    # Create IMG file
    truncate -s 20G "${output_target}/${image_name}.img"

    # GPT partitions
    _loopdevice=$(losetup -f --show "${output_target}/${image_name}.img" 2> /dev/null || \
                  { echo 'Failed to create loop device'; exit 1; } )
    if ! echo 'label: gpt' | udevadm lock --device="${_loopdevice}" -- \
            sfdisk -W always -- "${_loopdevice}" &> /dev/null; then
        echo 'Failed to create new gpt partition table!'
        exit 1
    fi
    sleep 3
    partprobe -- "${_loopdevice}"

    if ! echo -e ",${_espsize}MiB,C12A7328-F81F-11D2-BA4B-00A0C93EC93B,\n,+,L,\n" | \
            udevadm lock --device="${_loopdevice}" -- sfdisk --append  -W always -- "${_loopdevice}" &> /dev/null; then
        echo 'Failed to create partitions!'
        exit 1
    fi
    sleep 3
    partprobe -- "${_loopdevice}"

    if ! udevadm lock --device="${_loopdevice}p1" -- \
             mkfs.fat -F32 -n "${_esplabel}" -- "${_loopdevice}p1" &> /dev/null; then
         echo 'Formating partition #1 failed!'
        exit 1
    fi
    if ! udevadm lock --device="${_loopdevice}p2" -- \
            mkfs.btrfs -L "${_rootlabel}" -q -- "${_loopdevice}p2" &> /dev/null; then
        echo 'Formating partition #2 failed!'
        exit 1
    fi

    printf '\e[1;34m-->\e[0m\e[1m Mounting partitions\e[0m\n'
    # Mount partitions
    install -d -m 0755 -- "${worktmp}/imgp1"
    install -d -m 0755 --  "${worktmp}/imgp2"
    mount -- "${_loopdevice}p1" "${worktmp}/imgp1"
    mount -o compress=zstd -- "${_loopdevice}p2" "${worktmp}/imgp2"
}

declare -r worktmp='/var/tmp/arkdep-img'

_create_img

export ARKDEP_NO_BOOTCTL=1 ARKDEP_ROOT=${worktmp}/imgp2 ARKDEP_BOOT=${worktmp}/imgp1

arkdep init

cp -v $output_target/$image_name.tar.zst ${worktmp}/imgp2/arkdep/cache
mkdir -p ${worktmp}/imgp1/loader/entries
mkdir -p ${worktmp}/imgp1/EFI/{BOOT,systemd}

# Run post-init script if exists
if [[ -f $variantdir/extensions/post_init.sh ]]; then
	printf '\e[1;34m-->\e[0m\e[1m Running post-init extension\e[0m\n'
	(source $variantdir/extensions/post_init.sh)
fi

arkdep deploy cache $image_name

owner=$(awk -F : 'NR == 2 { print $3":"$4 }' ${ARKDEP_ROOT}/arkdep/overlay/etc/passwd)
homedir=$(awk -F : 'NR == 2 { print $1 }' ${ARKDEP_ROOT}/arkdep/overlay/etc/passwd)

# Add user
mkdir -p ${ARKDEP_ROOT}/arkdep/shared/home/$homedir
chown $owner ${ARKDEP_ROOT}/arkdep/shared/home/$homedir

# Add skel files to user
printf "\e[1;34m-->\e[0m\e[1m Adding SKEL files in ${ARKDEP_ROOT}/arkdep/shared/home/$homedir\e[0m\n"
mkdir -p ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/Desktop
chown $owner ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/Desktop
cp -v ${ARKDEP_ROOT}/arkdep/deployments/$image_name/rootfs/etc/skel/Desktop/org.shadowblip.Logout.desktop ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/Desktop/org.shadowblip.Logout.desktop
chmod +x ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/Desktop/org.shadowblip.Logout.desktop
chown $owner ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/Desktop/org.shadowblip.Logout.desktop
cp -v ${ARKDEP_ROOT}/arkdep/deployments/$image_name/rootfs/etc/skel/Desktop/com.steampowered.Logout.desktop ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/Desktop/com.steampowered.Logout.desktop
chmod +x ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/Desktop/com.steampowered.Logout.desktop
chown $owner ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/Desktop/com.steampowered.Logout.desktop
cp -v ${ARKDEP_ROOT}/arkdep/deployments/$image_name/rootfs/etc/skel/.zshrc ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/.zshrc
chown $owner ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/.zshrc
mkdir -p ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/.config
chown $owner ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/.config
cp -v ${ARKDEP_ROOT}/arkdep/deployments/$image_name/rootfs/etc/skel/.config/kwinrc ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/.config/kwinrc
chown $owner ${ARKDEP_ROOT}/arkdep/shared/home/$homedir/.config/kwinrc

printf "\e[1;34m-->\e[0m\e[1m Creating SWAP file\e[0m\n"
btrfs filesystem mkswapfile --size 6G ${ARKDEP_ROOT}/arkdep/shared/swapfile

cp ${ARKDEP_ROOT}/arkdep/deployments/$image_name/rootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi \
${ARKDEP_BOOT}/EFI/systemd
cp ${ARKDEP_ROOT}/arkdep/deployments/$image_name/rootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi \
${ARKDEP_BOOT}/EFI/BOOT/BOOTx64.EFI
cat <<- END > ${worktmp}/imgp1/loader/loader.conf
timeout 0
console-mode max
editor yes
auto-entries yes
auto-firmware yes
END

_umount_img
rm -rf "${worktmp}/imgp1" "${worktmp}/imgp2"
sleep 2
tar --transform 's/.*\///g' -cv -I 'zstd -12 -T0 ' -f "${output_target}/${image_name}.img.tar.zst" \
"${output_target}/${image_name}.img"
printf '\e[1;34m-->\e[0m\e[1m Creating checksum files\e[0m\n'
sha256sum "${output_target}/${image_name}.img.tar.zst" > "${output_target}/${image_name}.img.tar.zst.sha256"
sha256sum "${output_target}/${image_name}.img" > "${output_target}/${image_name}.img.sha256"
printf '\e[1;34m-->\e[0m\e[1m Done\e[0m\n'
