mv /etc/init/mesos-master.conf /root
mv /etc/init/zookeeper.conf /root

# ip
MY_IP=`ifconfig eth0|grep "inet addr"|awk -F":" '{print $2}'| awk '{print $1}'`
echo "IP=$MY_IP" >> /etc/default/mesos-slave

# hostname
HOSTNAME="slave$SLAVE_NO"
echo "${HOSTNAME}" > /etc/hostname

# /etc/hosts
sed s/plgubuntu/"${HOSTNAME}"/g /etc/hosts > /etc/hosts.new
cp /etc/hosts /etc/hosts.old
mv /etc/hosts.new /etc/hosts
echo "${MASTER_IP}	master" >> /etc/hosts

# zookeeper
echo "zk://master:2181/mesos" > /etc/mesos/zk

# startup script overwrite
echo "#!/bin/sh -e" > /etc/rc.local
echo "sudo /usr/lib/hadoop/sbin/hadoop-daemon.sh start datanode" >> /etc/rc.local

reboot
