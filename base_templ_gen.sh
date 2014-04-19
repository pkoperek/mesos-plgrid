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

if [ ! -f ~/.ssh/id_rsa.pub ]
then
  echo "Error - could not find generated key"
  exit
fi

TS=`date +%s`
OUTTMP_F="/tmp/onetmptempl.$USER.$TS"
HNAME=${CLUSTER_NAME}-master
SSHKEY=`cat ~/.ssh/id_rsa.pub`
TEMPLATE_NAME="$CLUSTER_NAME-master-$TS"

echo -n "Generating base template ($TEMPLATE_NAME)..."
generateTemplate "$TEMPLATE_NAME" "$IMGID" "$NETID" "$HNAME" "$SSHKEY" "$OUTTMP_F"
echo Done.

CLEAN_UP=$CLUSTER_NAME-master_cleanup.sh

# initialize clean up script
rm -f $CLEAN_UP
touch ${CLEAN_UP}
chmod +x ${CLEAN_UP}
echo "#!/bin/bash" >> ${CLEAN_UP}

echo -n "Uploading template..."
BASE_TEMPLATE_ID=`onetemplate create $OUTTMP_F | grep ID | awk -F':' '{print $2}'|tr -d ' '`
echo "onetemplate delete ${BASE_TEMPLATE_ID}" >> ${CLEAN_UP}
echo "Done. Template ID: ${BASE_TEMPLATE_ID}"

echo "Starting base node for customization..."
BASE_VM_ID=`onetemplate instantiate ${BASE_TEMPLATE_ID} | grep ID | awk -F':' '{print $2}'|tr -d ' '`
echo "onevm shutdown $BASE_VM_ID" >> ${CLEAN_UP}
echo "onevm delete $BASE_VM_ID" >> ${CLEAN_UP}
	
BASE_IP=`onevm show ${BASE_VM_ID} |grep IP|awk -F'"' '{print $2}'`
waitUntilState $BASE_VM_ID "ACTIVE"
echo "Done. Internal IP: ${BASE_IP}"

echo -n "Forwarding ssh..."
IPPORT_LINE=`expect -c "log_file expect.log
	spawn oneport -a $BASE_IP -p 22 
	expect \"Username:  \" 
	send $USER\n
	expect \"Password:  \"
	send $PASS\n
	interact
"`
echo "Done."

BASE_IPPORT_OUT=`echo "$IPPORT_LINE"|grep ">"| awk -F"->" '{print $1}'`
BASE_IP_OUT=`echo "$BASE_IPPORT_OUT"|awk -F":" '{print $1}'|tr -d ' '`
BASE_IP_OUT=`echo "$BASE_IP_OUT"|awk '{print $1}'`
BASE_PORT_OUT=`echo "$BASE_IPPORT_OUT"|awk -F":" '{print $2}'|tr -d ' '`

echo "Master access forwarded to: $BASE_IP_OUT $BASE_PORT_OUT (\"ssh -p "$BASE_PORT_OUT" root@"$BASE_IP_OUT"\")"
echo "Copying installation script ..."
uploadFile "${BASE_IP_OUT}" "${BASE_PORT_OUT}" "mesos_install.sh"
echo "Done."

echo -n "Executing installation script..."
ssh -oStrictHostKeyChecking=no -p "$BASE_PORT_OUT" root@"${BASE_IP_OUT}" 'chmod +x mesos_install.sh && ./mesos_install.sh' >& mesos_installation.log
echo "Done."

echo "Storing mesos-ready image..."
echo -n "Generating image ID..."
BASE_IMAGE_ID=`onevm saveas $BASE_VM_ID $CLUSTER_NAME-base-image|grep "Image ID"|awk -F":" '{print $2}'|tr -d ' '`
echo "oneimage delete $BASE_IMAGE_ID" >> $CLEAN_UP
echo "Done. Base ID: $BASE_IMAGE_ID"

echo -n "Storing the image..."
onevm shutdown $BASE_VM_ID
waitUntilState $BASE_VM_ID "DONE"
echo "Done."

echo -n "Starting master..."



echo "Cleaning up ($OUTTMP_F)"
rm -f $OUTTMP_F expect.log
