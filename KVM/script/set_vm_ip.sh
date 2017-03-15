#!/bin/bash
ip=$1
ssh_id=$2
new_ip=$3
if [$new_ip != "ip"]; then
  new_ip=$ip
fi



if [ $ssh_id = "centos" ]; then
echo -e 'DEVICE="eth0"\nBOOTPROTO="static"\nONBOOT="yes"\nTYPE="Ethernet"\nUSERCTL="yes"\nBROADCAST=192.168.1.255\nGATEWAY=192.168.1.1\nIPADDR='${new_ip}'\nNETMASK=255.255.255.0' > /mnt/kvm/scripts/ifcfg-eth0
scp  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /mnt/kvm/scripts/ifcfg-eth0 centos@${ip}:ifcfg-eth0
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t centos@${ip} sudo cp /home/centos/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t centos@${ip} sudo service network restart 
elif [ $ssh_id = "ubuntu" ]; then  
echo -e "auto eth0\niface eth0 inet static\naddress ${new_ip}\nnetmask 255.255.255.0\nnetwork 192.168.1.0\nbroadcast 192.168.1.255\ngateway 192.168.1.1\ndns-nameservers 8.8.8.8" > /mnt/kvm/scripts/eth0.cfg
scp  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /mnt/kvm/scripts/eth0.cfg ubuntu@${ip}:eth0.cfg
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t ubuntu@${ip} sudo cp /home/ubuntu/eth0.cfg /etc/network/interfaces.d/eth0.cfg
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t ubuntu@${ip} sudo reboot
fi