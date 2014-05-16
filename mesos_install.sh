#!/bin/bash

# Needs root access!!!

UBUNTU_VERSION="12.04"
MESOS_VERSION="mesos_0.18.0_amd64"

apt-get update
apt-get upgrade -y

apt-get install zookeeperd openjdk-7-jdk default-jdk python-setuptools python-protobuf curl htop -y

curl -sSfL http://downloads.mesosphere.io/master/ubuntu/${UBUNTU_VERSION}/${MESOS_VERSION}.deb --output /tmp/mesos.deb
dpkg -i /tmp/mesos.deb

curl -sSfL http://downloads.mesosphere.io/master/ubuntu/${UBUNTU_VERSION}/${MESOS_VERSION}.egg --output /tmp/mesos.egg
easy_install /tmp/mesos.egg
