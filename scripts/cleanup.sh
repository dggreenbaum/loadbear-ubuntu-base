# Remove items used for building, since they aren't needed anymore

apt-get -y remove linux-headers-$(uname -r) build-essential
apt-get -y autoremove
apt-get clean

#Clean up tmp
echo "cleaning up tmp"
rm -rf /tmp/*
