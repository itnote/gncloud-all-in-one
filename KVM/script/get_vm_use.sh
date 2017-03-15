#!/bin/bash

ip=$2
user=$3
if [ $1 = "cpu" ]; then
 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}@${ip}  top -bn2 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'
elif [ $1 = "mem" ]; then
 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}@${ip} free | grep Mem | awk '{ print $3*1024 }'
elif [ $1 = "disk" ]; then
 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}@${ip} df -P | grep -v ^Filesystem | awk '{sum += $3} END { print sum*1024}'
elif [ $1 = "net" ]; then
 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${user}@${ip} netstat -i | grep eth0 | awk '{print $3}'
fi

