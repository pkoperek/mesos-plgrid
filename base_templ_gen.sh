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
OUTTMP_F="/tmp/base.$USER.$TS"
MASTER_TMP_OUT="/tmp/master.$USER.$TS"
SLAVE_TMP_OUT="/tmp/slave.$USER.$TS"
HNAME=${CLUSTER_NAME}-master
SSHKEY=`cat ~/.ssh/id_rsa.pub`
TEMPLATE_NAME="$CLUSTER_NAME-base-$TS"
MASTER_TEMPLATE_NAME="$CLUSTER_NAME-master-$TS"
SLAVE_TEMPLATE_NAME="$CLUSTER_NAME-slave-$TS"

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

echo "Setting up base VM..."
setupVM "$USER" "$PASS" "$BASE_IP" "mesos_install.sh" 
echo "Done."

echo "Storing mesos-ready image..."
echo -n "Generating image ID..."
BASE_IMAGE_ID=`onevm saveas $BASE_VM_ID 0 $CLUSTER_NAME-base-image|grep "Image ID"|awk -F":" '{print $2}'|tr -d ' '`
echo "oneimage delete $BASE_IMAGE_ID" >> $CLEAN_UP
echo "Done. Base ID: $BASE_IMAGE_ID"

echo -n "Storing the image..."
onevm shutdown $BASE_VM_ID
waitUntilState $BASE_VM_ID "DONE"
echo "Done."

echo -n "Generating templates for customized image..."
generateTemplate "$MASTER_TEMPLATE_NAME" "$BASE_IMAGE_ID" "$NETID" "master" "$SSHKEY" "$MASTER_TMP_OUT"
generateTemplate "$SLAVE_TEMPLATE_NAME" "$BASE_IMAGE_ID" "$NETID" "slave" "$SSHKEY" "$SLAVE_TMP_OUT"
echo "Done."

echo -n "Upload customized templates..."
MASTER_TEMPLATE_ID=`onetemplate create $MASTER_TMP_OUT | grep ID | awk -F':' '{print $2}'|tr -d ' '`
SLAVE_TEMPLATE_ID=`onetemplate create $SLAVE_TMP_OUT | grep ID | awk -F':' '{print $2}'|tr -d ' '`
echo "Done."

echo -n "Starting master..."
MASTER_VM_ID=`onetemplate instantiate ${BASE_TEMPLATE_ID} | grep ID | awk -F':' '{print $2}'|tr -d ' '`
waitUntilState $MASTER_VM_ID "ACTIVE"
MASTER_IP=`onevm show ${MASTER_VM_ID} |grep IP|awk -F'"' '{print $2}'`
echo "Done. Master VM ID: ${MASTER_VM_ID} / IP: ${MASTER_IP}"

echo "Setting up master VM..."
setupVM "$USER" "$PASS" "$MASTER_IP" "master_setup.sh"
echo "Done."

echo "Cleaning up ($OUTTMP_F)"
rm -f $OUTTMP_F expect.log $MASTER_TMP_OUT $SLAVE_TMP_OUT
