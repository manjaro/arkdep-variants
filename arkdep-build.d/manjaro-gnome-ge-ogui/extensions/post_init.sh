#!/bin/sh

# Keep user changes
sed -i -e 's|backup_user_accounts=.*|backup_user_accounts=1|' ${ARKDEP_ROOT}/arkdep/config

# Set default image
sed -i -e "s|repo_default_image=.*|repo_default_image='manjaro-ge-ogui'|" ${ARKDEP_ROOT}/arkdep/config

# Set deploy_keep to 2
sed -i -e 's|deploy_keep=.*|deploy_keep=2|' ${ARKDEP_ROOT}/arkdep/config

# Ensure passwd/group/shadow permissions are set properly
chmod 600 $variantdir/overlay/post_init/etc/shadow
chmod 644 $variantdir/overlay/post_init/etc/{passwd,group}
# Write $variantdir/overlay/post_init
for f in $(ls $variantdir/overlay/post_init/); do
	cp -rv $variantdir/overlay/post_init/$f ${ARKDEP_ROOT}/arkdep/overlay/
done
