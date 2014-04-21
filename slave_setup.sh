mv /etc/init/mesos-master.conf /root
mv /etc/init/zookeeper.conf /root

# ip
MY_IP=`ifconfig eth0|grep "inet addr"|awk -F":" '{print $2}'| awk '{print $1}'`
echo "IP=$MY_IP" >> /etc/default/mesos-slave

# hostname
echo "slave$SLAVE_NO" > /etc/hostname

# master ip
echo "zk://${MASTER_IP}:2181/mesos" > /etc/mesos/zk

reboot
