#!/bin/bash

# 지앤클라우드 all in one 버전 설치
# root, gncloud 계정 생성 - 비밀번호 gnc=1151
yum -y update
# 도커 서비스를 위해 호스트 이름은 manager로 세팅
systemctl disable firewalld
systemctl stop firewalld
       setsebool httpd_can_network_connect on -P


mkdir -p /var/log/gncloud
ln -s /home/data /data
mkdir -p /data/mysql
mkdir -p /data/registry
mkdir -p /data/local/images/kvm/instance
mkdir -p /data/nas/images/kvm/base
mkdir -p /data/nas/images/kvm/snapshot
mkdir -p /data/nas/images/kvm/backup

# docker install
>/etc/yum.repos.d/docker.repo echo '[dockerrepo]' >> /etc/yum.repos.d/docker.repo
echo 'name=Docker Repository' >> /etc/yum.repos.d/docker.repo
echo 'baseurl=https://yum.dockerproject.org/repo/main/centos/7/' >> /etc/yum.repos.d/docker.repo
echo 'enabled=1' >> /etc/yum.repos.d/docker.repo echo 'gpgcheck=1' >> /etc/yum.repos.d/docker.repo
echo 'gpgkey=https://yum.dockerproject.org/gpg' >> /etc/yum.repos.d/docker.repo
# yum -y install docker-engine
# libvirtd와 docker가 서로 상호 동작 하기 위해서 docker 버전을 1.12.5로 맞추어야 한다.
# 그렇지않으면  DHCP 서버로 부터 KVM 인스턴스가 IP를 얻어오지 못한다.
yum install docker-1.12.5

# kvm libvirt 를 위한 네트워크 세팅
> /etc/sysconfig/network-scripts/ifcfg-br0
echo “DEVICE=br0>> /etc/sysconfig/network-scripts/ifcfg-br0
echo “TYPE=Bridge>> /etc/sysconfig/network-scripts/ifcfg-br0
echo “BOOTPROTO=static>> /etc/sysconfig/network-scripts/ifcfg-br0
echo “ONBOOT=yes>> /etc/sysconfig/network-scripts/ifcfg-br0
echo “DELAY=0>> /etc/sysconfig/network-scripts/ifcfg-br0
echo “IPADDR=192.168.1.5>> /etc/sysconfig/network-scripts/ifcfg-br0
echo “NETMASK=255.255.255.0>> /etc/sysconfig/network-scripts/ifcfg-br0
echo “GATEWAY=192.168.1.1>> /etc/sysconfig/network-scripts/ifcfg-br0
echo “DNS1=168.126.63.1>> /etc/sysconfig/network-scripts/ifcfg-br0
#
>/etc/sysconfig/network-scripts/ifcfg-enp2s0
echo “TYPE=Ethernet” >>/etc/sysconfig/network-scripts/ifcfg-enp2s0
echo “BOOTPROTO=static” >>/etc/sysconfig/network-scripts/ifcfg-enp2s0
echo “NAME=enp2s0” >>/etc/sysconfig/network-scripts/ifcfg-enp2s0
echo “DEVICE=enp2s0” >>/etc/sysconfig/network-scripts/ifcfg-enp2s0
echo “ONBOOT=yes” >>/etc/sysconfig/network-scripts/ifcfg-enp2s0
echo “BRIDGE=br0 ” >>/etc/sysconfig/network-scripts/ifcfg-enp2s0

systemctl disable NetworkManager
systemctl restart network
systemctl stop NetworkManager
chkconfig network on
#

# docker 디렉토리를 /data로 옮김
mv /var/lib/docker /data/docker
ln -s /data/docker docker

# docker registry 설정 및 호스트 아이피 등록
vi /usr/lib/systemd/system/docker.service
ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --insecure-registry docker-registry:5000
vi /etc/hosts
192.168.1.5  docker-registry 추가
#

yum -y install epel-release
yum -y install git
mkdir /data/git
cd git
git clone https://github.com/gncloud/gncloud.git
mkdir -p /var/lib/gncloud/KVM/script/initcloud
cp -R /data/git/gncloud/KVM/script/* /var/lib/gncloud/KVM/script/initcloud/.
chmod 777 /var/lib/gncloud/KVM/script/initcloud/*sh

# libvirt 설치
yum -y install qemu-kvm libvirt virt-install bridge-utils install arp-scan genisoimage

# ssh key 생성 및 내부 컨테이너 접근이 가능하도록 키 복사
ssh-keygen -f ~/.ssh/id_rsa
cp ~/.ssh/id_rsa.pub authorized_keys

# user-data 생성
cp -R initcloud/ /var/lib/libvirt/.
> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "#cloud-config" >> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "password: fastcat=1151" >> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "chpasswd: {expire: False}" >> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "ssh_pwauth: true" >> /var/lib/gncloud/KVM/script/initcloud/user-data
echo "ssh_authorized_keys:" >> /var/lib/gncloud/KVM/script/initcloud/user-data
cat ~/.ssh/id_rsa.pub >> /var/lib/gncloud/KVM/script/initcloud/user-data
vi user-data
ssh-rsa 앞에 -와 공백을  삽입한다.

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
virsh pool-autostart default
virsh pool-autostart gnpool

# 베이스이미지가 있는 호스트에서 베이스이비지 복사
scp root@192.168.1.2:/data/nas/images/kvm/base/* /data/nas/images/kvm/base/.


# docker-compose install
curl -L "https://github.com/docker/compose/releases/download/1.11.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# docker 그룹으로 gncloud의 그룹 변경 /etc/passwd
## login gncloud
# su - gncloud
# cp /data/git/gncloud/docker-compose.yml .
# docker-compose up
# docker swarm init --advertise-addr 192.168.1.5

