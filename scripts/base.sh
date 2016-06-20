
# Apt-install various things necessary for Ruby, guest additions,
# etc., and remove optional things to trim down the machine.
apt-get -y update
apt-get -y upgrade
apt-get -y install gcc build-essential linux-headers-$(uname -r) zlib1g-dev libssl-dev libreadline-gplv2-dev libyaml-dev vim curl nfs-common
apt-get clean
