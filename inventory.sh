#/bin/bash

> docker_inventory

for i in $(docker ps -q)
do ip=$(docker inspect $i |grep '"IPAddress":' |cut -d ':' -f 2 |cut -d '"' -f 2 |head -n 1) ; group=$(docker inspect $i |grep 'Platform":' |cut -d ':' -f 2 |cut -d '"' -f 2 |head -n 1) ; host_ubuntu=$(docker inspect $i |grep 'ubuntu' |cut -d ':' -f 2 |cut -d '"' -f 2 | cut -d '/' -f 2 | cut -d '_' -f 1 |head -n 1) ; host_centos=$(docker inspect $i |grep 'centos' |cut -d ':' -f 2 |cut -d '"' -f 2 | cut -d '/' -f 2 | cut -d '_' -f 1 |head -n 1)
	if [ "$host_ubuntu" == "ubuntu" ]
	then	
 	echo $host_ubuntu"-"$i ansible_host=$ip >> docker_inventory
else 
	echo $host_centos"-"$i ansible_host=$ip >> docker_inventory
fi
done
sed -i 1i[$group] docker_inventory
#echo $group
