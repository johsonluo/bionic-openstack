#!/bin/bash -x

# need to manually run the following:
# pvcreate /dev/sdb
# vgcreate cinder-volumes /dev/sdb

if [ "$#" -ne 1 ]; then
    export IP_ADDR=$(hostname -I | cut -d' ' -f1)
else
    export IP_ADDR=$1
fi

export DEBIAN_FRONTEND=noninteractive

source passwords.sh

apt install software-properties-common
add-apt-repository -y cloud-archive:stein
apt update
apt -y dist-upgrade

apt -y install crudini

#
# Cinder
#
apt -y install lvm2 thin-provisioning-tools

apt -y install cinder-volume

crudini --merge /etc/cinder/cinder.conf <<EOF
[database]
connection = mysql+pymysql://cinder:$CINDER_DBPASS@controller/cinder

[DEFAULT]
transport_url = rabbit://openstack:$RABBIT_PASS@controller
auth_strategy = keystone
my_ip = $IP_ADDR
enabled_backends = lvm
glance_api_servers = http://controller:9292

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = $CINDER_PASS

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm
volume_clear_size=50

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp
EOF

service tgt restart
service cinder-volume restart

cd /etc
git commit -a -m "cinder installation"
