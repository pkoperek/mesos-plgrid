#!/bin/bash

SPARK_VERSION=spark-1.0.0-bin-hadoop2

wget "http://d3kbcqa49mib13.cloudfront.net/${SPARK_VERSION}.tgz"
tar zxvf "${SPARK_VERSION}.tgz"

cp "${SPARK_VERSION}/conf/spark-env.sh.template" "${SPARK_VERSION}/conf/spark-env.sh"
echo "export MESOS_NATIVE_LIBRARY=/usr/local/lib/libmesos.so" >> "${SPARK_VERSION}/conf/spark-env.sh"
echo "export SPARK_EXECUTOR_URI=http://d3kbcqa49mib13.cloudfront.net/spark-1.0.0-bin-hadoop2.tgz" >> "${SPARK_VERSION}/conf/spark-env.sh"
echo "-Djava.net.preferIPv4Stack=true" >> "${SPARK_VERSION}/conf/java-opts"

git clone https://github.com/pkoperek/nibbler.git

cat <<EOF > automate.sh
#!/bin/bash
sudo -u hdfs hdfs dfs -mkdir /datasets
sudo -u hdfs hdfs dfs -chown root:root /datasets
pushd nibbler
./gradlew distZip
unzip build/distributions/nibbler.zip
EOF

chmod +x automate.sh
