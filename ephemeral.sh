#!/bin/bash

#NOTE: This script run once on instance creation.
#      If instance is stopped and started, likely to lose your existing ephemeral drives


instance_id=`curl http://169.254.169.254/2016-09-02/meta-data/instance-id`

all_disks=$(lsblk -d -n | grep disk | awk '{print $1}')
esb_disks=$(aws ec2 describe-instances --region=eu-west-1 --instance-id=$instance_id --query 'Reservations[*].Instances[*].BlockDeviceMappings[*].[DeviceName, Ebs.VolumeId]' --output text | awk '{print $1}' | sed -e 's/\/dev\///g' -e 's/sd/xvd/g' | cut -c1-4)

ephemeral_disks=$(echo ${esb_disks} ${all_disks} | tr ' ' '\n' | sort | uniq -u)

for disk in $ephemeral_disks; do
  echo "Disk - $disk .."

  pvcreate /dev/$disk --yes
  vgcreate vg_one /dev/$disk --yes
  lvcreate -l 100%VG -n lv_one vg_one --yes
done


if [[ ! -z "$ephemeral_disks" ]]
then
   mkfs.ext4 /dev/vg_one/lv_one
   mount /dev/vg_one/lv_one /opt

   #update fstab to keep logical volume mounted on reboot.
   #use "nofail" to cover off missing logical volume
   echo '/dev/vg_one/lv_one  /opt  auto  defaults,nofail  0  2' >> /etc/fstab
fi
