/usr/bin/apt-get -y install cloud-init cloud-initramfs-rescuevol cloud-initramfs-growroot python-setuptools

rm /etc/default/grub
cat >> /etc/default/grub << EOF
GRUB_DEFAULT=0
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0 net.ifnames=0"
GRUB_CMDLINE_LINUX=""
GRUB_RECORDFAIL_TIMEOUT=0

# Uncomment to disable graphical terminal (grub-pc only)
GRUB_TERMINAL=console
EOF

/usr/sbin/update-grub

cp /etc/cloud/templates/hosts.debian.tmpl /etc/cloud/templates/hosts.ubuntu.tmpl

# Reduce DHCP timeout
sed -i '/timeout 300;/c\timeout 10;' /etc/dhcp/dhclient.conf

# Don't wait so long for network devices to come up
sed -i '/TimeoutStartSec/c\TimeoutStartSec=10sec' /etc/systemd/system/network-online.target.wants/networking.service

########## BEGIN CLOUD INIT CFG ##########
cat > /etc/cloud/cloud.cfg << EOF
# The top level settings are used as module
# and system configuration.

# A set of users which may be applied and/or used by various modules
# when a 'default' entry is found it will reference the 'default_user'
# from the distro configuration specified below
users:
   - default

# If this is set, 'root' will not be able to ssh in and they
# will get a message to login instead as the above $user (ubuntu)
disable_root: true

# This will cause the set+update hostname module to not operate (if true)
preserve_hostname: false

# Example datasource config
# datasource:
#    Ec2:
#      metadata_urls: [ 'blah.com' ]
#      timeout: 5 # (defaults to 50 seconds)
#      max_wait: 10 # (defaults to 120 seconds)

# The modules that run in the 'init' stage
cloud_init_modules:
 - migrator
 - ubuntu-init-switch
 - seed_random
 - bootcmd
 - write-files
 - growpart
 - resizefs
 - set_hostname
 - update_hostname
 - update_etc_hosts
 - ca-certs
 - rsyslog
 - users-groups
 - ssh

# The modules that run in the 'config' stage
cloud_config_modules:
# Emit the cloud config ready event
# this can be used by upstart jobs for 'start on cloud-config'.
 - emit_upstart
 - disk_setup
 - mounts
 - ssh-import-id
 - locale
 - set-passwords
 - snappy
 - grub-dpkg
 - apt-pipelining
 - apt-configure
 - package-update-upgrade-install
 - fan
 - landscape
 - timezone
 - disable-ec2-metadata
 - runcmd
 - byobu

# The modules that run in the 'final' stage
cloud_final_modules:
 - rightscale_userdata
 - scripts-vendor
 - scripts-per-once
 - scripts-per-boot
 - scripts-per-instance
 - scripts-user
 - ssh-authkey-fingerprints
 - keys-to-console
 - phone-home
 - final-message
 - power-state-change

# System and/or distro specific settings
# (not accessible to handlers/transforms)
system_info:
   # This will affect which distro class gets used
   distro: ubuntu
   # Default user name + that default users groups (if added/used)
   default_user:
     name: ubuntu
     lock_passwd: True
     gecos: Ubuntu
     groups: [adm, audio, cdrom, dialout, dip, floppy, netdev, plugdev, sudo, video]
     sudo: ["ALL=(ALL) NOPASSWD:ALL"]
     shell: /bin/bash
   # Other config here will be given to the distro class and/or path classes
   paths:
      cloud_dir: /var/lib/cloud/
      templates_dir: /etc/cloud/templates/
      upstart_dir: /etc/init/
   package_mirrors:
     - arches: [i386, amd64]
       failsafe:
         primary: http://archive.ubuntu.com/ubuntu
         security: http://security.ubuntu.com/ubuntu
       search:
         primary:
           - http://%(ec2_region)s.ec2.archive.ubuntu.com/ubuntu/
           - http://%(availability_zone)s.clouds.archive.ubuntu.com/ubuntu/
           - http://%(region)s.clouds.archive.ubuntu.com/ubuntu/
         security: []
     - arches: [armhf, armel, default]
       failsafe:
         primary: http://ports.ubuntu.com/ubuntu-ports
         security: http://ports.ubuntu.com/ubuntu-ports
   ssh_svcname: ssh

EOF
########## END CLOUD INIT CFG ##########

########## BEGIN CLOUD INIT LOGGING ##########
cat > /etc/cloud/cloud.cfg.d/05_logging.cfg << EOF
## This yaml formated config file handles setting
## logger information.  The values that are necessary to be set
## are seen at the bottom.  The top '_log' are only used to remove
## redundency in a syslog and fallback-to-file case.
##
## The 'log_cfgs' entry defines a list of logger configs
## Each entry in the list is tried, and the first one that
## works is used.  If a log_cfg list entry is an array, it will
## be joined with '\n'.
_log:
 - &log_base |
   [loggers]
   keys=root,cloudinit

   [handlers]
   keys=consoleHandler,cloudLogHandler

   [formatters]
   keys=simpleFormatter,arg0Formatter

   [logger_root]
   level=DEBUG
   handlers=consoleHandler,cloudLogHandler

   [logger_cloudinit]
   level=DEBUG
   qualname=cloudinit
   handlers=
   propagate=1

   [handler_consoleHandler]
   class=StreamHandler
   level=WARNING
   formatter=arg0Formatter
   args=(sys.stderr,)

   [formatter_arg0Formatter]
   format=%(asctime)s - %(filename)s[%(levelname)s]: %(message)s

   [formatter_simpleFormatter]
   format=[CLOUDINIT] %(filename)s[%(levelname)s]: %(message)s
 - &log_file |
   [handler_cloudLogHandler]
   class=FileHandler
   level=DEBUG
   formatter=arg0Formatter
   args=('/var/log/cloud-init.log',)
 - &log_syslog |
   [handler_cloudLogHandler]
   class=handlers.SysLogHandler
   level=DEBUG
   formatter=simpleFormatter
   args=("/dev/log", handlers.SysLogHandler.LOG_USER)

log_cfgs:
# These will be joined into a string that defines the configuration
 - [ *log_base, *log_syslog ]
# These will be joined into a string that defines the configuration
 - [ *log_base, *log_file ]
# A file path can also be used
# - /etc/log.conf

# this tells cloud-init to redirect its stdout and stderr to
# 'tee -a /var/log/cloud-init-output.log' so the user can see output
# there without needing to look on the console.
output: {all: '| tee -a /var/log/cloud-init-output.log'}

EOF
########## END CLOUD INIT LOGGING ##########

########## BEGIN CLOUD INIT DHC COMMON ##########
cat >> /etc/cloud/cloud.cfg.d/99_dreamcompute_common.cfg << EOF
# Configuration for DreamCompute.
manage_etc_hosts: template
datasource_list: [ ConfigDrive ]

disable_root: 1
ssh_pwauth: 0

datasource:
  ConfigDrive:
      dsmode: local

growpart:
  mode: auto
  devices: ['/']

resize_rootfs: True
locale_configfile: /etc/sysconfig/i18n
mount_default_fields: [~, ~, 'auto', 'defaults,nofail', '0', '2']

resize_rootfs_tmp: /dev

system_info:
   default_user:
     name: dhc-user
     lock_passwd: True
     gecos: DreamCompute User
     groups: [adm, audio, cdrom, dialout, dip, floppy, netdev, plugdev, sudo, video]
     sudo: ["ALL=(ALL) NOPASSWD:ALL"]
     shell: /bin/bash
   distro: ubuntu
   package_mirrors:
     - arches: [i386, amd64]
       failsafe:
         primary: http://archive.ubuntu.com/ubuntu
         security: http://security.ubuntu.com/ubuntu
       search:
         primary:
           - http://mirrors.dreamcompute.com/ubuntu/
           - http://%(availability_zone)s.dreamcompute.archive.ubuntu.com/ubuntu/
           - http://dreamcompute.archive.ubuntu.com/ubuntu/
         security: []
     - arches: [armhf, armel, default]
       failsafe:
         primary: http://ports.ubuntu.com/ubuntu-ports
         security: http://ports.ubuntu.com/ubuntu-ports

EOF
########## END CLOUD INIT DHC COMMON ##########

cat >> /etc/resolvconf/resolv.conf.d/base << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
search nodes.dreamcompute.net
EOF
