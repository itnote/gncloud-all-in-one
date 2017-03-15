 #!/bin/bash

vm_name=$1
bridge_name="br0"

mac_address=`virsh dumpxml ${vm_name} | grep "mac address" | cut -d "'" -f 2`

arp_scan_record=`arp-scan --interface ${bridge_name} -l | grep $mac_address`

ip_address=`echo -n ${arp_scan_record} | cut -d " " -f 1`

echo -n "${ip_address}"