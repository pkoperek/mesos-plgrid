#!/bin/bash

mv /etc/init/mesos-slave.conf /root

# ip
MY_IP=`ifconfig eth0|grep "inet addr"|awk -F":" '{print $2}'| awk '{print $1}'`
echo "IP=$MY_IP" >> /etc/default/mesos-master

# hostname
echo "master" > /etc/hostname

cp /etc/hosts /etc/hosts.old
sed s/plgubuntu/master/g /etc/hosts | sed s/"127.0.1.1"/"#127.0.1.1"/g > /etc/hosts.new
echo "${MY_IP}          master" > /etc/hosts
cat /etc/hosts.new >> /etc/hosts

# zookeeper
ln -s /usr/bin/zookeeper-server /etc/init.d/zookeeper-server
update-rc.d zookeeper-server defaults

# hdfs
mkdir /hdfs
chown -R hdfs:hdfs /hdfs
sudo -u hdfs /usr/lib/hadoop/bin/hadoop namenode -format

# startup script overwrite
echo "#!/bin/sh -e" > /etc/rc.local
echo "sudo -u hdfs /usr/lib/hadoop/sbin/hadoop-daemon.sh start namenode" >> /etc/rc.local

# execute custom_master.sh
if [ -f custom_master.sh ]; then
	echo "Executing customizations..."
	chmod +x custom_master.sh
	./custom_master.sh
fi
