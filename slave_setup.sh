#!/bin/bash

mv /etc/init/mesos-master.conf /root
mv /etc/init/zookeeper.conf /root

echo "zk://${MASTER_IP}:2181/mesos" > /etc/mesos/zk

reboot
