# Create vagrant user
groupadd vagrant
useradd -s /bin/bash -m vagrant -g vagrant

# Set up sudo
echo 'vagrant ALL=NOPASSWD:ALL' > /etc/sudoers.d/vagrant

# Installing vagrant keys
mkdir /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh

# Install the vbox guest additions
mkdir /mnt/VBoxGuestAdditions
mount /home/install/VBoxGuestAdditions.iso /mnt/VBoxGuestAdditions
sh /mnt/VBoxGuestAdditions/VBoxLinuxAdditions.run

# Cleanup the vbox guest additions
umount /mnt/VBoxGuestAdditions
rmdir /mnt/VBoxGuestAdditions
rm /home/install/VBoxGuestAdditions.iso
