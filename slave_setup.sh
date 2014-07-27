mv /etc/init/mesos-master.conf /root
mv /etc/init/zookeeper.conf /root

# ip
MY_IP=`ifconfig eth0|grep "inet addr"|awk -F":" '{print $2}'| awk '{print $1}'`
echo "IP=$MY_IP" >> /etc/default/mesos-slave

# more time to download and setup spark
mkdir /etc/mesos-slave
echo "15mins" > /etc/mesos-slave/executor_registration_timeout

# hostname
HOSTNAME="slave$SLAVE_NO"
echo "${HOSTNAME}" > /etc/hostname

# /etc/hosts
cp /etc/hosts /etc/hosts.old
sed s/plgubuntu/"${HOSTNAME}"/g /etc/hosts > /etc/hosts.new
echo "${MY_IP}         ${HOSTNAME}" > /etc/hosts
cat /etc/hosts.new >> /etc/hosts
echo "${MASTER_IP}	master" >> /etc/hosts

# zookeeper
echo "zk://master:2181/mesos" > /etc/mesos/zk

# startup script overwrite
echo "#!/bin/sh -e" > /etc/rc.local
echo "sudo -u hdfs /usr/lib/hadoop/sbin/hadoop-daemon.sh start datanode" >> /etc/rc.local

reboot
