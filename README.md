Starting mesos cluster on PL Grid.
==================================

  * Initialize environment

```
module cloud/rest-api-client
voms-proxy-init
```

  * Clone this repo

```
git clone git@github.com:pkoperek/mesos-plgrid.git
```

  * Specify configuration options in settings.sh

```
PASS="YourPassword"
CLUSTER_NAME=alpha-by-default
IMGID=8 # change if you want different distro than ubuntu 12.04
NETID=0
SLAVES_COUNT=2
```

  * Run `./cluster_gen.sh`

  * Run `$ ./spark_upload.sh alpha-access.txt ../spark-0.9.1-hadoop_2.0.0-mr1-cdh4.4.0-bin.tar.gz /tmp`

  * Copy output and execute scp commands 

Sample `spark-env.sh`
=====================

```
export MESOS_NATIVE_LIBRARY=/usr/local/lib/libmesos.so
export SPARK_EXECUTOR_URI=/tmp/spark-0.9.1-hadoop_2.0.0-mr1-cdh4.4.0-bin.tar.gz
export MASTER=zk://localhost:2181/mesos
```

Todo:
=====

  * use `CLUSTER` /etc/default/mesos-* setting as cluster name
