
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
CLUSTER_NAME=alpha-by-default
IMGID=8 # change if you want different distro than ubuntu 12.04
NETID=0
SLAVES_COUNT=2
CLIENT_SSH_KEY="ssh-keygen additional key for accessing cloud vms user@machine"
```

  * Run `./cluster_gen.sh`

Running `spark shell`
=====================

  * Create  `spark-env.sh` in `SPARK_HOME/conf` with following contents

```
export MESOS_NATIVE_LIBRARY=/usr/local/lib/libmesos.so
export SPARK_EXECUTOR_URI=http://d3kbcqa49mib13.cloudfront.net/spark-1.0.0-bin-hadoop2.tgz
```

  * Run the shell with following command:
  
`./bin/spark-shell --master mesos://zk://master:2181/mesos`
  
  * One-liner to check if REPL works: 

```  
scala> sc.parallelize(1 to 10000).filter(_<10).collect()
```

Todo:
=====

  * use `CLUSTER` /etc/default/mesos-* setting as cluster name
  * fail with meaningful message when image isn't stored correctly
