#!/bin/bash

mv /etc/init/mesos-slave.conf /root

# ip
MY_IP=`ifconfig eth0|grep "inet addr"|awk -F":" '{print $2}'| awk '{print $1}'`
echo "IP=$MY_IP" >> /etc/default/mesos-master

# hostname
echo "master" > /etc/hostname

reboot
