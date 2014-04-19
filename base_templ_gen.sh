#!/bin/bash

#set -x

set -eu

source settings.sh
source common.sh

set +u
if [ -z "$PASS" ]; then
  echo "Need to specify password in credentials.sh!"
  exit
fi

set -u

TS=`date +%s`
OUTTMP_F="/tmp/onetmptempl.$USER.$TS"

HNAME=${CLUSTER_NAME}-master

if [ ! -f ~/.ssh/id_rsa.pub ]
then
  echo 'Error - could not found generated key'
  exit
fi

SSHKEY=`cat ~/.ssh/id_rsa.pub`
TEMPLATE_NAME="$CLUSTER_NAME-master-$TS"

echo -n "Generating base template ($TEMPLATE_NAME)..."
generateTemplate $TEMPLATE_NAME $IMGID $NETID $HNAME $SSHKEY $OUTTMP_F

echo Done.

CLEAN_UP=$CLUSTER_NAME-master_cleanup.sh

rm -f $CLEAN_UP
touch ${CLEAN_UP}
chmod +x ${CLEAN_UP}
echo "#!/bin/bash" >> ${CLEAN_UP}

echo 'Uploading template'

TEMPLATE_ID=`onetemplate create $OUTTMP_F | grep ID | awk -F':' '{print $2}'|tr -d ' '`
echo "onetemplate delete ${TEMPLATE_ID}" >> ${CLEAN_UP}

echo "Uploaded ${TEMPLATE_ID}"

VM_ID=`onetemplate instantiate ${TEMPLATE_ID} | grep ID | awk -F':' '{print $2}'|tr -d ' '`
echo "onevm shutdown $VM_ID" >> ${CLEAN_UP}
echo "onevm delete $VM_ID" >> ${CLEAN_UP}
	
MASTER_IP=`onevm show ${VM_ID} |grep IP|awk -F'"' '{print $2}'`
echo "Master node started with IP: ${MASTER_IP}"

waitUntilState $VM_ID "RUNNING"

echo "Forwarding ssh..."

IPPORT_LINE=`expect -c "log_file expect.log
	spawn oneport -a $MASTER_IP -p 22 
	expect \"Username:  \" 
	send $USER\n
	expect \"Password:  \"
	send $PASS\n
	interact
"`

echo "Port forwarding done ..."

MASTER_IPPORT_OUT=`echo "$IPPORT_LINE"|grep ">"| awk -F"->" '{print $1}'`
MASTER_IP_OUT=`echo "$MASTER_IPPORT_OUT"|awk -F":" '{print $1}'|tr -d ' '`
MASTER_IP_OUT=`echo "$MASTER_IP_OUT"|awk '{print $1}'`
MASTER_PORT_OUT=`echo "$MASTER_IPPORT_OUT"|awk -F":" '{print $2}'|tr -d ' '`

echo "Master access forwarded to: $MASTER_IP_OUT $MASTER_PORT_OUT (\"ssh -p "$MASTER_PORT_OUT" root@"$MASTER_IP_OUT"\")"
echo "Copying installation script ..."

set +eu
SCP="scp -oBatchMode=yes -oStrictHostKeyChecking=no -P ${MASTER_PORT_OUT} mesos_install.sh root@${MASTER_IP_OUT}:mesos_install.sh"
	
$SCP
while [ "$?" != "0" ]; do
	echo "Retrying ..." 
	sleep 3
	$SCP
done
set -eu

echo "Executing installation script..."

ssh -oStrictHostKeyChecking=no -p "$MASTER_PORT_OUT" root@"${MASTER_IP_OUT}" 'chmod +x mesos_install.sh && ./mesos_install.sh' >& mesos_installation.log

echo "Storing mesos-ready image..."

BASE_IMAGE_ID=`onevm saveas $VM_ID $CLUSTER_NAME-base-image|grep "Image ID"|awk -F":" '{print $2}'|tr -d ' '`
	
onevm shutdown $VM_ID

waitUntilState $VM_ID "DONE"


echo "Cleaning up ($OUTTMP_F)"
rm -f $OUTTMP_F expect.log
