#!/bin/bash
#Configure the LVS Server with ipvsadm and keepalived

apt-get install ipvsadm

apt-get install keepalived

apt-get install apache2

if [ -f LVS.conf ]
then
	source LVS.conf
	#load interface, router_id, lvs_ip, type, priority, real_server, 
	#    lvs_port, real_server_port
else
	echo "Can not load file LVS.conf"
	exit 1
fi

exec 6>&1
exec 1>/etc/keepalived/keepalived.conf

( cat <<EOF
global_defs {  
	notification_email {  
	 	root@localhost  
	}  
	notification_email_from root@localhost  
	smtp_server localhost  
	smtp_connect_timeout 30  
	router_id  $router_id  
}

vrrp_script chk_apache2 {  
	script "/usr/local/check_apache2.sh"  
	interval 2  
	weight 2  
}

vrrp_instance VI_1 {  
	state $type    
	interface $interface
	virtual_router_id 51 
	priority $priority 
	advert_int 1 
	authentication {
		auth_type PASS  
		auth_pass 1111  
	}  
	virtual_ipaddress {
		$lvs_ip/32
	}

	track_script 
	{  
		chk_apache2
	}
}

virtual_server $lvs_ip $lvs_port {

	delay_loop 1

	lb_algo $balance_algorithm

	lb_kind DR

	persistence_timeout $persistence_timeout

	protocol $protocol

	# Real Server 1 configuration
EOF
)

for server in ${real_server[*]}
do
	( cat <<EOF
	real_server $server $real_server_port {

		weight 1

		TCP_CHECK {

			connection_timeout 10

			nb_get_retry 3

			delay_before_retry 3

		}
	}
EOF
 )
done

echo "}"


#/usr/local/check_apache2.sh
exec 1>/usr/local/check_apache2.sh
( cat <<EOF
#!/bin/bash

if !(service apache2 status | grep "running")
then
	service apache2 restart
	sleep 5
	if !(service apache2 status | grep "running")
	then
		killall keepalived
	fi
fi
EOF
 )

exec 1>&6
exec 6>&-

echo "/etc/keepalived/keepalived.conf Configures OK"
echo "/usr/local/check_apache2.sh Configures OK"

echo "service ipvsadm start">>/etc/rc.local
echo "service apache2 start">>/etc/rc.local
echo "service keepalived start">>/etc/rc.local
service ipvsadm restart
service apache2 restart
service keepalived restart
echo "LVS server Configures OK"

exit 0