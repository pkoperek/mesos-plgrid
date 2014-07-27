#!/bin/bash

wget http://d3kbcqa49mib13.cloudfront.net/spark-1.0.0-bin-hadoop2.tgz
tar zxvf spark-1.0.0-bin-hadoop2.tgz

cp spark*/conf/spark-env.sh.template spark*/conf/spark-env.sh
echo "export MESOS_NATIVE_LIBRARY=/usr/local/lib/libmesos.so" >> spark*/conf/spark-env.sh
echo "export SPARK_EXECUTOR_URI=http://d3kbcqa49mib13.cloudfront.net/spark-1.0.0-bin-hadoop2.tgz" >> spark*/conf/spark-env.sh
echo "-Djava.net.preferIPv4Stack=true" >> spark*/conf/java-opts

git clone https://github.com/pkoperek/nibbler.git
