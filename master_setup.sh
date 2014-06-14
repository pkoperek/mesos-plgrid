#!/bin/bash

mv /etc/init/mesos-slave.conf /root

# ip
MY_IP=`ifconfig eth0|grep "inet addr"|awk -F":" '{print $2}'| awk '{print $1}'`
echo "IP=$MY_IP" >> /etc/default/mesos-master

# hostname
echo "master" > /etc/hostname

sed s/plgubuntu/master/g /etc/hosts > /etc/hosts.new
cp /etc/hosts /etc/hosts.old
mv /etc/hosts.new /etc/hosts

# zookeeper
ln -s /usr/bin/zookeeper-server zookeeper-server
update-rc.d zookeeper-server defaults

# hdfs
chown -R hdfs:hdfs /hdfs
sudo -u hdfs /usr/lib/hadoop/bin/hadoop namenode -format

reboot
