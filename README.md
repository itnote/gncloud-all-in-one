# 지앤클라우드 올인원 버전 인스톨 가이드 (CentOS7) - 설치 시간 약 50분 내외, 네트워크 등의 상황에 따라 변동이 있을 수 있음


<span></span>
## 1. PC, workstation, server 등 CentOS7 설치 (minimal 설치 시 설치 시간 약 20분)
-------------

- CentOS7 ISO 이미지 다운로


    ```
    # libvirt의 manager 관리를 위하여 gnome으로 설치한다.
    # 다운로드 링크
    http://mirror.oasis.onnetcorp.com/centos/7/isos/x86_64/CentOS-7-x86_64-DVD-1611.iso
    http://ftp.neowiz.com/centos/7/isos/x86_64/CentOS-7-x86_64-DVD-1611.iso
    http://data.nicehosting.co.kr/os/CentOS/7/isos/x86_64/CentOS-7-x86_64-DVD-1611.iso
    http://ftp.daumkakao.com/centos/7/isos/x86_64/CentOS-7-x86_64-DVD-1611.iso
    http://centos.mirror.cdnetworks.com/7/isos/x86_64/CentOS-7-x86_64-DVD-1611.iso
    http://ftp.kaist.ac.kr/CentOS/7/isos/x86_64/CentOS-7-x86_64-DVD-1611.iso
    http://mirror.navercorp.com/centos/7/isos/x86_64/CentOS-7-x86_64-DVD-1611.iso
    ```


<span></span>
## 2. docker 설치 (7분)
-------------

- 사전 작업 (약 2분)


    ```
    # 패키지 업데이트
    yum -y update

    # 방화벽 내리기
    systemctl disable firewalld
    systemctl stop firewalld

    # selinux disabled
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

    # 디렉토리 생성
    mkdir -p /var/log/gncloud

    # 자동 파티션으로 centos7을 설치 할 경우 /home에 대부분의 HDD 공간을 할당
    mkdir -p /home/data
    ln -s /home/data /data # /data 디렉토리를 /home/data와 연결

    # 컨트롤러 중 데이터베이스와 레지스트리의 공간을 할당
    mkdir -p /data/mysql
    mkdir -p /data/registry

    # 실제 인스턴스가 실행되는 디렉토리
    mkdir -p /data/local/images/kvm/instance

    # 인스턴스의 기본 이미지나 백업, 스냅샷 등을 저장하는 디렉토리
    mkdir -p /data/nas/images/kvm/base
    mkdir -p /data/nas/images/kvm/snapshot
    mkdir -p /data/nas/images/kvm/backup
    ```
- 네트워크 정보 세팅
    ```
    yum -y install net-tools

    # 네트워크 정보 저장
    export IPADDR=`ip addr | grep inet | grep -v inet6 | grep -v 127.0.0.1 | tr -s ' ' |  cut -d' ' -f3 | cut -d/ -f1`
    export IP_HEAD=`echo $IPADDR | cut -d'.' -f1-2`
    export GATEWAY=`netstat -rn | grep $IP_HEAD | grep UG | tr -s ' ' | cut -d' ' -f2`
    export NETMASK=`netstat -rn | grep $IP_HEAD | grep -v UG | tr -s ' ' | cut -d' ' -f3`
    export NET_NAME=ifcfg-$(netstat -rn | grep $IP_HEAD | grep UG | tr -s ' ' | cut -d' ' -f 8)
    ```
- docker 1.12.5 버전 설치 (5분 내외)


    ```
    # docker yum repo 설정
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

    # docker 서비스 레지스트리 등 세팅
  	sed -i "s/DOCKER_NETWORK_OPTIONS=/DOCKER_NETWORK_OPTIONS=-H tcp:\/\/0.0.0.0:2375 -H unix:\/\/\/var\/run\/docker.sock/g" /etc/sysconfig/docker-network
   	sed -i "s/DOCKER_STORAGE_OPTIONS=/DOCKER_STORAGE_OPTIONS=--insecure-registry docker-registry:5000/g" /etc/sysconfig/docker-storage
   	sed -i "s/true/false/g" /etc/docker/daemon.json

    #vi /etc/sysconfig/docker-network
    #DOCKER_NETWORK_OPTIONS=-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock
    #vi /etc/sysconfig/docker-storage
    #DOCKER_STORAGE_OPTIONS=--insecure-registry docker-registry:5000
    # swarm mode enable
    #vi /etc/docker/daemon.json
    #false

    # docker-registry /etc/hosts에 추가
    echo "$IPADDR docker-registry" >> /etc/hosts

    # docker 서비스 시작
    docker enable docker
    docker start docker
    ```

<span></span>
## 3. libvirtd 설치 (6분)
-------------

- 사전 작업 (1분)

    ```
    # 네트워크 세팅
    > /etc/sysconfig/network-scripts/ifcfg-br0
    echo “DEVICE=br0>> /etc/sysconfig/network-scripts/ifcfg-br0
    echo “TYPE=Bridge>> /etc/sysconfig/network-scripts/ifcfg-br0
    echo “BOOTPROTO=static>> /etc/sysconfig/network-scripts/ifcfg-br0
    echo “ONBOOT=yes>> /etc/sysconfig/network-scripts/ifcfg-br0
    echo “DELAY=0>> /etc/sysconfig/network-scripts/ifcfg-br0

    # IP를 고정시키기 위해 IP정보와 GATEWAY정보를 얻어야 함
    echo "IPADDR=$IPADDR" >> /etc/sysconfig/network-scripts/ifcfg-br0
    echo "NETMASK=$NETMASK" >> /etc/sysconfig/network-scripts/ifcfg-br0
    echo "GATEWAY=$GATEWAY" >> /etc/sysconfig/network-scripts/ifcfg-br0
    echo "DNS1=8.8.8.8" >> /etc/sysconfig/network-scripts/ifcfg-br0

    # network interface 이름이 eth0 또는 enp2s0 등

    >/etc/sysconfig/network-scripts/$NET_NAME
    echo "TYPE=Ethernet" >>/etc/sysconfig/network-scripts/$NET_NAME
    echo "BOOTPROTO=static" >>/etc/sysconfig/network-scripts/$NET_NAME
    echo "NAME=$NET_NAME" >>/etc/sysconfig/network-scripts/$NET_NAME
    echo "DEVICE=$NET_NAME" >>/etc/sysconfig/network-scripts/$NET_NAME
    echo "ONBOOT=yes" >>/etc/sysconfig/network-scripts/$NET_NAME
    echo "BRIDGE=br0" >>/etc/sysconfig/network-scripts/$NET_NAME

    # NetworkManager는 disable 해야 하고 network를 이용함
    systemctl disable NetworkManager
    systemctl stop NetworkManager
    systemctl restart network
    chkconfig network on
    ```

- libvirtd 설치 (2분)

    ```
    # 설치
    yum -y install qemu-kvm libvirt virt-install bridge-utils install arp-scan genisoimage
    systemctl enable libvirtd
    systemctl start libvirtd
    ```

- 설치 후 작업 (3분)

    ```
    # git 설치 및 실행에 필요한 스크립트 등 다운로드
    yum -y install epel-release
    yum -y install git
    mkdir -p /data/git
    cd /data/git
    git clone https://github.com/gncloud/gncloud-all-in-one.git

    # 실제 수행 디렉토리 생성 및 복사
    mkdir -p /var/lib/gncloud/KVM

    cp -R /data/git/gncloud/KVM /var/lib/gncloud/KVM
    chmod 777 /var/lib/gncloud/KVM/script/*sh

    # ssh key 생성 및 내부 컨테이너 접근이 가능하도록 키 복사
    ssh-keygen -f ~/.ssh/id_rsa
    cp ~/.ssh/id_rsa.pub authorized_keys

    # user-data 생성
    > /var/lib/gncloud/KVM/script/initcloud/user-data
    echo "#cloud-config" >> /var/lib/gncloud/KVM/script/initcloud/user-data
    echo "password: fastcat=1151" >> /var/lib/gncloud/KVM/script/initcloud/user-data
    echo "chpasswd: {expire: False}" >> /var/lib/gncloud/KVM/script/initcloud/user-data
    echo "ssh_pwauth: true" >> /var/lib/gncloud/KVM/script/initcloud/user-data
    echo "runcmd:" >> /var/lib/gncloud/KVM/script/initcloud/user-data
    echo " - [ sh, -c, echo \" `cat ~/.ssh/id_rsa.pub`\" >> ~/.ssh/authorized_keys ] " >> \
        /var/lib/gncloud/KVM/script/initcloud/user-data

    # 기본  가상 네트워크 삭제
    virsh net-destroy default

    cd ~
    # libvirt pool 생성
    # pool.xml 파일 HDD의 크기에 따라 용량을 다르게 함
    > pool.xml
    echo "<pool type='dir'>" >> pool.xml
    echo "   <name>gnpool</name>" >> pool.xml
    echo "   <capacity unit='G'>330</capacity>" >> pool.xml
    echo "   <allocation unit='G'>20</allocation>" >> pool.xml
    echo "   <available unit='G'>350</available>" >> pool.xml
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

    # libvirt pool 정의 및 자동 실행
    virsh pool-define pool.xml
    virsh pool-start default
    virsh pool-start gnpool
    virsh pool-autostart default
    virsh pool-autostart gnpool
    ```

<span></span>
## 4. 베이스 이미지 복사 (usb로 복사 시 약 5분)
-------------

- 베이스 이미지 다운로드

    ```
    # centos6.8
    http://cloud.centos.org/centos/6/images/CentOS-6-x86_64-GenericCloud.qcow2
    # centos7
    http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
    # ubuntu 14.04
    https://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
    # ubuntu 16.04
    https://cloud-images.ubuntu.com/releases/16.04/release/ubuntu-16.04-server-cloudimg-amd64-disk1.img
    # ubuntu 16.10
    https://cloud-images.ubuntu.com/releases/16.10/release/ubuntu-16.10-server-cloudimg-amd64.img

    # 다운로드 후 /data/nas/images/kvm/base 디렉토리 아래 복사

   ```

<span></span>
## 5. docker compose 설치 및 지앤클라우드 올인원 실행 (8분)
-------------

- docker compose 설치

    ```
    # curl을 통한 실행 파일 다운로드
    curl -L "https://github.com/docker/compose/releases/download/1.11.1/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose

    chmod +x /usr/local/bin/docker-compose

    # 지앤클라우드 올인원 실행
    # selinux 를 해결 하기 위해 지앤클라우드 올인원을 실행 하기 전에 리부팅 필요
    cp /var/lib/gncloud-all-in-one/docker-compose.yml ~/.
    cd ~
    docker-compose up -d

    docker swarm init --advertise-addr $IPADDR
    ```

