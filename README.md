
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

Customization of machines
=========================

If any customization is needed please create `custom_master.sh` or `custom_slave.sh` file respectively.
Those files should contain any commands which need to be executed at the end of installation - after 
all other tools have been installed and configured, but before the final reboot.

Running `spark shell`
=====================

  * Create  `spark-env.sh` in `$SPARK_HOME/conf` with following contents

```
export MESOS_NATIVE_LIBRARY=/usr/local/lib/libmesos.so
export SPARK_EXECUTOR_URI=http://d3kbcqa49mib13.cloudfront.net/spark-1.0.0-bin-hadoop2.tgz
```

  * Create `java-opts` in `$SPARK_HOME/conf` with following contents

```
-Djava.net.preferIPv4Stack=true
```

  * Run the shell with following command:
  
`./bin/spark-shell --master mesos://zk://master:2181/mesos`
  
  * One-liner to check if REPL works: 

```  
scala> sc.parallelize(1 to 10000).filter(_<10).collect()
```

Restarting mesos services
=========================

To restart/start/stop mesos services on cluster machines use `service` command (comes from Ubuntu `upstart`).

```
service mesos-slave stop 
service mesos-slave start
```

Note: there is no restart command! To restart a service use `stop` and then `start`

Preparing sample datasets without using diskspace for unpacking
===============================================================

```
root@master:~# sudo -u hdfs hdfs dfs -mkdir -p /datasets
root@master:~# sudo -u hdfs hdfs dfs -chown -R root /datasets
root@master:~# gunzip dataset.txt.gz -c | hdfs dfs -put - /datasets/eurusd_full.txt
```

Todo:
=====

  * use `CLUSTER` /etc/default/mesos-* setting as cluster name
  * fail with meaningful message when image isn't stored correctly
  * add  '--executor_registration_timeout=10mins' on slaves - downloading spark takes more than 1min
