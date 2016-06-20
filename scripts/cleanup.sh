# Remove items used for building, since they aren't needed anymore

apt-get -y remove linux-headers-$(uname -r) build-essential
apt-get -y autoremove
apt-get clean

#Clean up tmp
echo "cleaning up tmp"
rm -rf /tmp/*

echo "Installing firstboot script"
cat >> /etc/init.d/firstboot << EOF
#! /bin/bash
# Remove install user on first boot
sed -i '/install/d' /etc/passwd
sed -i '/install/d' /etc/shadow
sed -i '/install/d' /etc/group
rm -rf /home/install
rm -f /etc/init.d/firstboot
EOF
echo "Configuring firstboot to run on boot"
chmod +x /etc/init.d/firstboot
update-rc.d firstboot defaults
