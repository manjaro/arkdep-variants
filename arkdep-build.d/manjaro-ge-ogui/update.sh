# update config file
sed -i -e "s|repo_default_image=.*|repo_default_image='manjaro-ge-ogui'|" $arkdep_dir/config
sed -i -e 's|deploy_keep=.*|deploy_keep=2|' $arkdep_dir/config
sed -i -e "s|migrate_files=.*|migrate_files=('var/usrlocal' 'var/opt' 'var/srv' 'var/lib/AccountsService' 'var/lib/bluetooth' 'var/lib/NetworkManager' 'var/lib/arkane' 'var/lib/manjaro-branch' 'var/lib/power-profiles-daemon' 'var/db' 'etc/localtime' 'etc/locale.gen' 'etc/locale.conf' 'etc/NetworkManager/system-connections' 'etc/ssh')|" $arkdep_dir/config

# migrate new files
source $arkdep_dir/config
# Migrate specified files and directories
if [[ ${#migrate_files[@]} -ge 1 ]] && [[ ! -n $ARKDEP_ROOT ]]; then
	printf '\e[1;34m-->\e[0m\e[1m Migrating local files to new deployment\e[0m\n'
	for file in ${migrate_files[@]}; do
		[[ ! -e /$file ]] && continue
		printf "Copying $file\n"
		cp -r /$file $arkdep_dir/deployments/${data[0]}/rootfs/${file%/*}
	done
fi

# update network config
[[ -L /etc/NetworkManager/system-connections ]] && cp /var/nm-system-connections/* $arkdep_dir/deployments/${data[0]}/rootfs/etc/NetworkManager/system-connections/
[[ -e $arkdep_dir/deployments/${data[0]}/rootfs/var/nm-system-connections ]] && rm -rf $arkdep_dir/deployments/${data[0]}/rootfs/var/nm-system-connections

# force -steamdeck option in desktop mode to prevent constant steam updates
[[ -e /home/gamer/Desktop/steam.desktop ]] && sed -i 's,Exec=/usr/bin/steam-runtime,Exec=/usr/bin/steam -steamdeck,' /home/gamer/Desktop/steam.desktop

# Arkdep is pre EFI var drop version
if [[ -f $arkdep_boot/loader/entries/${data[0]}.conf ]]; then
	mv $arkdep_boot/loader/entries/${data[0]}.conf $arkdep_boot/loader/entries/$(date +%Y%m%d-%H%M%S)-${data[0]}+3.conf
	bootctl set-default ''
fi
