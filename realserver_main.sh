#!/bin/sh

apt-get install apache2

VIP=$1

cur_dir=`pwd`

program=${cur_dir}/realserver_config.sh

chmod +x realserver_config.sh

if [ -n "$1" ]
then
	if ./realserver_config.sh $VIP start
	then
		echo "Real server configures and starts OK"
	else
		echo "Configure Failed"
		exit 1
	fi
else
	echo "Usage: $0 {Virtual IP}"  
       	exit 1
fi

service apache2 restart

echo "$program $VIP start">>/etc/rc.local
echo "service apache2 start">>/etc/rc.local
chmod +x /etc/rc.local

exit 0
