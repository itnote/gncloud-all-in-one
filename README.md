# 지앤클라우드 올인원 버전 인스톨 가이드 (CentOS7)

## 목차
1. PC, workstation, server 등 CentOS7 설치
2. docker 설치




<span></span>

1. PC, workstation, server 등 CentOS7 설치
-------------

- CentOS7 ISO 이미지 다운로

    - libvirt의 manager 관리를 위하여 gnome으로 설치한다.

    ```
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
2. docker 설치
-------------

- 사전 작업

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

- docker 1.12.5 버전 설치


    ```
    >/etc/yum.repos.d/docker.repo echo '[dockerrepo]' >> /etc/yum.repos.d/docker.repo
    echo 'name=Docker Repository' >> /etc/yum.repos.d/docker.repo
    echo 'baseurl=https://yum.dockerproject.org/repo/main/centos/7/' >> /etc/yum.repos.d/docker.repo
    echo 'enabled=1' >> /etc/yum.repos.d/docker.repo echo 'gpgcheck=1' >> /etc/yum.repos.d/docker.repo
    echo 'gpgkey=https://yum.dockerproject.org/gpg' >> /etc/yum.repos.d/docker.repo
    # yum -y install docker-engine
    # libvirtd와 docker가 서로 상호 동작 하기 위해서 docker 버전을 1.12.5로 맞추어야 한다.
    # 그렇지않으면  DHCP 서버로 부터 KVM 인스턴스가 IP를 얻어오지 못한다.
    yum -y install docker-1.12.5

    # docker 디렉토리를 /data로 옮김
    mv /var/lib/docker /data/docker
    ln -s /data/docker /var/lib/docker

    # docker 서비스 레지스트리 등 세팅
    vi /usr/lib/systemd/system/docker.service
    ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --insecure-registry docker-registry:5000

    # docker-registry IP 등록
    vi /etc/hosts
    [IP]  docker-registry
    # IP 확인은
    #﻿ip addr | grep inet | grep -v inet6 | grep -v 127.0.0.1 | tr -s ' ' | cut -d' ' -f3 | cut -d/ -f1 결과
    # echo "`ip addr | grep inet | grep -v inet6 | grep -v 127.0.0.1 | tr -s ' ' | cut -d' ' -f3 | cut -d/ -f1` docker-registry" >> /etc/hosts

    ```
