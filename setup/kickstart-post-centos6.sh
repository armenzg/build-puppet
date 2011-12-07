install
cmdline
######## ADD YOUR URL HERE:
url --url=xxx
lang en_US.UTF-8
keyboard us
network --device eth0 --bootproto dhcp
######## ADD A ROOT PW HASH HERE:
rootpw  --iscrypted xxx
firewall --disabled
authconfig --enableshadow --passalgo=sha512 --enablefingerprint
selinux --disabled
timezone --utc America/Los_Angeles
bootloader --location=mbr --driveorder=sda --append="crashkernel=auto"
firstboot --disabled

# The following is the partition information you requested
# Note that any partitions you deleted are not expressed
# here so unless you clear all partitions first, this is
# not guaranteed to work
clearpart --all --drives=sda --initlabel
part /boot --fstype ext4 --size=100 --ondisk=sda
part swap --fstype swap --size 4096 --ondisk=sda
part / --fstype ext4 --size=1024 --grow --ondisk=sda

reboot

%packages
@core
# do not install rhgb, as it obscures the puppetize.sh run later
-rhgb

%post
# This script runs inside the chroot'd new filesystem during install.  It gets
# a puppet password from the kernel command line, and passes that to puppetize.sh
# in /root/deploypass.

set -x

# parameters

hgrepo="http://hg.mozilla.org/build/puppet"

# display output to the user

echo "== executing kickstart-post-centos6.sh =="

# get the PUPPET_PASS; this will be our key to getting a certificate down
# the line..

for word in $(</proc/cmdline); do
        case $word in
                PUPPET_PASS=*)
                    PUPPET_PASS="${word//PUPPET_PASS=}" ;;
        esac
done

if [ -z "$PUPPET_PASS" ]; then
    echo "PUPPET_PASS was not set; aborting setup."
fi

# install puppet and a few other things for setup, using the local mirrors
# (note that this assumes that the puppetmaster resolves as 'puppet')

mkdir -p /etc/yum.repos.d
rm -f /etc/yum.repos.d/*
cat > /etc/yum.repos.d/init.repo <<'EOF'
[epel]
name=epel
baseurl=http://puppet/yum/mirrors/epel/6/latest/$basearch/
enabled=1
gpgcheck=0

[releng-public]
name=releng-public
baseurl=http://puppet/yum/releng/public/noarch
enabled=1
gpgcheck=0

[os]
name=os
baseurl=http://puppet/yum/mirrors/centos/6.0/os/$basearch
enabled=1
gpgcheck=0

[updates]
name=os
baseurl=http://puppet/yum/mirrors/centos/6.0/latest/updates/$basearch
enabled=1
gpgcheck=0
EOF

# puppet: that's why we're here
# wget: used below
# openssh-clients: puppetize.sh uses ssh
# ntp: to synchronize time so certificates work
yum install -y puppet wget openssh-clients ntp || exit 1

# check that puppet is installed properly
if ! puppet --version >/dev/null; then
    echo "Puppet does not appear to be installed properly."
    exit 1
fi

# remove any existing yum repositories
rm -f /etc/yum.repos.d/*

# install the deploy key
echo $PUPPET_PASS > /root/deploypass
chmod 600 /root/deploypass

# set up the puppetize script to run at boot
# (NOTE: CentOS claims that /etc/resolv.conf is not correct if using DHCP, which
# would make this fail.  Yet, it works!)
wget -O/root/puppetize.sh "$hgrepo/raw-file/default/setup/puppetize.sh" || exit 1
chmod +x /root/puppetize.sh
(
    grep -v puppetize /etc/rc.d/rc.local
    echo 'echo "puppetize output is in puppetize.log"'
    echo '/bin/bash /root/puppetize.sh 2>&1 | tee /root/puppetize.log'
) > /etc/rc.d/rc.local~
mv /etc/rc.d/rc.local{~,}
chmod +x /etc/rc.d/rc.local
