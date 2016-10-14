#!/bin/bash  
# description: Config realserver
 
LVS_VIP=$1
  
case "$2" in
start)  
       /sbin/ifconfig lo:0 $LVS_VIP netmask 255.255.255.255 broadcast $LVS_VIP  
       /sbin/route add -host $LVS_VIP dev lo:0  
       echo "1" >/proc/sys/net/ipv4/conf/lo/arp_ignore  
       echo "2" >/proc/sys/net/ipv4/conf/lo/arp_announce  
       echo "1" >/proc/sys/net/ipv4/conf/all/arp_ignore  
       echo "2" >/proc/sys/net/ipv4/conf/all/arp_announce  
       sysctl -p >/dev/null 2>&1  
       echo "RealServer Start OK"  
       ;;  
stop)  
       /sbin/ifconfig lo:0 down  
       /sbin/route del $LVS_VIP >/dev/null 2>&1  
       echo "0" >/proc/sys/net/ipv4/conf/lo/arp_ignore  
       echo "0" >/proc/sys/net/ipv4/conf/lo/arp_announce  
       echo "0" >/proc/sys/net/ipv4/conf/all/arp_ignore  
       echo "0" >/proc/sys/net/ipv4/conf/all/arp_announce  
       echo "RealServer Stoped"  
       ;;  
*)  
       echo "Usage: $0 {start|stop}"  
       exit 1  
esac  
exit 0
