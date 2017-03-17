#!/bin/bash

# 지앤클라우드 all in one 버전 설치
# root, gncloud 계정 생성 - 비밀번호 gnc=1151
yum -y update
# 도커 서비스를 위해 호스트 이름은 manager로 세팅
systemctl disable firewalld
systemctl stop firewalld
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

yum -y install net-tools

# 네트워크 정보 저장
export IPADDR=`ip addr | grep inet | grep -v inet6 | grep -v 127.0.0.1 | tr -s ' ' |  cut -d' ' -f3 | cut -d/ -f1`
export IP_HEAD=`echo $IPADDR | cut -d'.' -f1-2`
export GATEWAY=`netstat -rn | grep $IP_HEAD | grep UG | tr -s ' ' | cut -d' ' -f2`
export NETMASK=`netstat -rn | grep $IP_HEAD | grep -v UG | tr -s ' ' | cut -d' ' -f3`
export NET_NAME=ifcfg-$(netstat -rn | grep $IP_HEAD | grep UG | tr -s ' ' | cut -d' ' -f 8)

mkdir -p /var/log/gncloud
mkdir -p /home/data
ln -s /home/data /data
mkdir -p /data/mysql
mkdir -p /data/registry
mkdir -p /data/local/images/kvm/instance
mkdir -p /data/nas/images/kvm/base
mkdir -p /data/nas/images/kvm/snapshot
mkdir -p /data/nas/images/kvm/backup

mkdir -p /var/lib/gncloud

# 베이스이비지 복사
# USB 등
# /data/nas/images/kvm/base 디렉토리에 복사


# kvm libvirt 를 위한 네트워크 세팅
# IPADDR, GATEWAY, NETMASK 는 직접 수정 하여야 한다
> /etc/sysconfig/network-scripts/ifcfg-br0
echo "DEVICE=br0" >> /etc/sysconfig/network-scripts/ifcfg-br0
echo "TYPE=Bridge" >> /etc/sysconfig/network-scripts/ifcfg-br0
echo "BOOTPROTO=static" >> /etc/sysconfig/network-scripts/ifcfg-br0
echo "ONBOOT=yes" >> /etc/sysconfig/network-scripts/ifcfg-br0
echo "DELAY=0" >> /etc/sysconfig/network-scripts/ifcfg-br0
echo "IPADDR=$IPADDR" >> /etc/sysconfig/network-scripts/ifcfg-br0
echo "NETMASK=$NETMASK" >> /etc/sysconfig/network-scripts/ifcfg-br0
echo "GATEWAY=$GATEWAY" >> /etc/sysconfig/network-scripts/ifcfg-br0
echo "DNS1=8.8.8.8" >> /etc/sysconfig/network-scripts/ifcfg-br0

#
>/etc/sysconfig/network-scripts/$NET_NAME
echo "TYPE=Ethernet" >>/etc/sysconfig/network-scripts/$NET_NAME
echo "BOOTPROTO=static" >>/etc/sysconfig/network-scripts/$NET_NAME
echo "NAME=$NET_NAME" >>/etc/sysconfig/network-scripts/$NET_NAME
echo "DEVICE=$NET_NAME" >>/etc/sysconfig/network-scripts/$NET_NAME
echo "ONBOOT=yes" >>/etc/sysconfig/network-scripts/$NET_NAME
echo "BRIDGE=br0" >>/etc/sysconfig/network-scripts/$NET_NAME

systemctl disable NetworkManager
systemctl restart network
systemctl stop NetworkManager
chkconfig network on
#


# docker install
>/etc/yum.repos.d/docker.repo echo '[dockerrepo]' >> /etc/yum.repos.d/docker.repo
echo 'name=Docker Repository' >> /etc/yum.repos.d/docker.repo
echo 'baseurl=https://yum.dockerproject.org/repo/main/centos/7/' >> /etc/yum.repos.d/docker.repo
echo 'enabled=1' >> /etc/yum.repos.d/docker.repo echo 'gpgcheck=1' >> /etc/yum.repos.d/docker.repo
echo 'gpgkey=https://yum.dockerproject.org/gpg' >> /etc/yum.repos.d/docker.repo
# libvirtd와 docker가 서로 상호 동작 하기 위해서 docker 버전을 1.12.5로 맞추어야 한다.
# 그렇지않으면  DHCP 서버로 부터 KVM 인스턴스가 IP를 얻어오지 못한다.
yum -y install docker-1.12.5

# docker 디렉토리를 /data로 옮김
mv /var/lib/docker /data/docker
ln -s /data/docker /var/lib/docker

# docker registry 설정 및 호스트 아이피 등록

#vi /usr/lib/systemd/system/docker.service
#ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --insecure-registry docker-registry:5000
#sed -i "s/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/0.0.0.0:2375 -H unix:\/\/\/var\/run\/docker.sock --insecure-registry docker-registry:5000/g" \
#/usr/lib/systemd/system/docker.service

# 1.12.5 버전은
#    vi /etc/sysconfig/docker-network
#    DOCKER_NETWORK_OPTIONS=-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock
sed -i "s/DOCKER_NETWORK_OPTIONS=/DOCKER_NETWORK_OPTIONS=-H tcp:\/\/0.0.0.0:2375 -H unix:\/\/\/var\/run\/docker.sock/g" /etc/sysconfig/docker-network
#    vi /etc/sysconfig/docker-storage
#    DOCKER_STORAGE_OPTIONS=--insecure-registry docker-registry:5000
sed -i "s/DOCKER_STORAGE_OPTIONS=/DOCKER_STORAGE_OPTIONS=--insecure-registry docker-registry:5000/g" /etc/sysconfig/docker-storage
# swarm mode enable
#    vi /etc/docker/daemon.json
#    false
sed -i "s/true/false/g" /etc/docker/daemon.json

# docker-registry /etc/hosts에 추가
echo "$IPADDR docker-registry" >> /etc/hosts

systemctl enable docker
systemctl start docker

yum -y install epel-release
yum -y install git
mkdir -p /data/git
cd /data/git
git clone https://github.com/gncloud/gncloud-all-in-one.git
cp -R /data/git/gncloud-all-in-one/KVM /var/lib/gncloud/KVM
cp /data/git/gncloud-all-in-one/docker-compose.yml ~/docker-compose.yml
chmod 777 /var/lib/gncloud/KVM/script/*sh

rm -rf /data/git

# libvirt 설치
yum -y install qemu-kvm libvirt virt-install bridge-utils install arp-scan genisoimage

# ssh key 생성 및 내부 컨테이너 접근이 가능하도록 키 복사
ssh-keygen -f ~/.ssh/id_rsa
cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

# user-data 생성
cp -R initcloud/ /var/lib/libvirt/.
> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "#cloud-config" >> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "password: fastcat=1151" >> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "chpasswd: {expire: False}" >> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "ssh_pwauth: true" >> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "runcmd:" >> /var/lib/gncloud/KVM/script/initcloud/user-data
echo " - [ sh, -c, echo \" `cat ~/.ssh/id_rsa.pub`\" >> ~/.ssh/authorized_keys ] " >> \
    /var/lib/gncloud/KVM/script/initcloud/user-data

systemctl enable libvirtd
systemctl start libvirtd
#
# 기본  가상 네트워크 삭제
virsh net-destroy default

cd ~
# libvirt pool 생성
# pool.xml 파일
> pool.xml
echo "<pool type='dir'>" >> pool.xml
echo "   <name>gnpool</name>" >> pool.xml
echo "   <capacity unit='bytes'>375809638400</capacity>" >> pool.xml
echo "   <allocation unit='bytes'>19379785728</allocation>" >> pool.xml
echo "   <available unit='bytes'>356429852672</available>" >> pool.xml
echo "   <source>" >> pool.xml
echo "   </source>" >> pool.xml
echo "   <target>" >> pool.xml
echo "     <path>/data/local/images/kvm/instance</path>" >> pool.xml
echo "     <permissions>" >> pool.xml
echo "       <mode>0755</mode>" >> pool.xml
echo "       <owner>0</owner>" >> pool.xml
echo "       <group>0</group>" >> pool.xml
echo "     </permissions>" >> pool.xml
echo "   </target>" >> pool.xml
echo " </pool>" >> pool.xml

virsh pool-define pool.xml
virsh pool-start default
virsh pool-start gnpool
virsh pool-autostart default
virsh pool-autostart gnpool

# docker-compose install
curl -L "https://github.com/docker/compose/releases/download/1.11.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# docker 그룹으로 gncloud의 그룹 변경 /etc/passwd
cp /data/git/gncloud-all-in-one/docker-compose.yml ~/.

# docker 버전에 따라 로그파일의 쓰기권한이 필요할수 있다
# chmod 777 /var
# chmod 777 /var/log
# chmod 777 /var/log/nginx
# chmod 777 /var/log/gncloud
cd ~
docker-compose up
docker swarm init --advertise-addr $IPADDR

