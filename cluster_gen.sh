#!/bin/bash

#set -x

set -eu

source settings.sh
source common.sh

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
CLUSTER_ACCESS="$CLUSTER_NAME-access.txt"
HOSTS_TMP=hosts.tmp
 
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
rm -f base_install.sh
# Add customization scripts if necessary
FILES_TO_COPY="base_install.sh hadoop-conf"
if [ -f custom_master.sh ]; then
	FILES_TO_COPY="${FILES_TO_COPY} custom_master.sh"
fi

if [ -f custom_slave.sh ]; then
	FILES_TO_COPY="${FILES_TO_COPY} custom_slave.sh"
fi

echo "Using following files for configuration: ${FILES_TO_COPY}"

# Using | instead of / because keys can contain /
sed -e "s|_CLIENT_SSH_KEY_PLACEHOLDER_|${CLIENT_SSH_KEY}|g" base_install.sh.template > base_install.sh
setupVM "$BASE_IP" "${FILES_TO_COPY}" "base_install.sh" ""
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
echo "onetemplate delete ${MASTER_TEMPLATE_ID}" >> ${CLEAN_UP}
SLAVE_TEMPLATE_ID=`onetemplate create $SLAVE_TMP_OUT | grep ID | awk -F':' '{print $2}'|tr -d ' '`
echo "onetemplate delete ${SLAVE_TEMPLATE_ID}" >> ${CLEAN_UP}
echo "Done."

echo -n "Starting master..."
MASTER_VM_ID=`onetemplate instantiate ${MASTER_TEMPLATE_ID} | grep ID | awk -F':' '{print $2}'|tr -d ' '`
echo "onevm shutdown $MASTER_VM_ID" >> ${CLEAN_UP}
waitUntilState $MASTER_VM_ID "ACTIVE"
MASTER_IP=`onevm show ${MASTER_VM_ID} |grep IP|awk -F'"' '{print $2}'`
echo "Done. Master VM ID: ${MASTER_VM_ID} / IP: ${MASTER_IP}"

echo "Setting up master VM..."
echo -n "master (${MASTER_IP}): " >> "$CLUSTER_ACCESS"
setupVM "$MASTER_IP" "master_setup.sh" "master_setup.sh" "$CLUSTER_ACCESS"
forwardPort "$MASTER_IP" "5050" "MASTER_GUI_IP" "MASTER_GUI_PORT"
forwardPort "$MASTER_IP" "22" "MASTER_OUT_IP" "MASTER_OUT_PORT"
echo "master gui: ${MASTER_GUI_IP}:${MASTER_GUI_PORT}" >> "$CLUSTER_ACCESS"
echo "Done."

HOSTS_PROPAGATION_LIST="${MASTER_OUT_IP}:${MASTER_OUT_PORT}"
echo "${MASTER_IP}      master" > ${HOSTS_TMP}

for I in `seq $SLAVES_COUNT`; do 
	echo "Starting slave: $I"
	SLAVE_VM_ID=`onetemplate instantiate ${SLAVE_TEMPLATE_ID} | grep ID | awk -F':' '{print $2}'|tr -d ' '`
	echo "onevm shutdown $SLAVE_VM_ID" >> ${CLEAN_UP}
	waitUntilState $SLAVE_VM_ID "ACTIVE"
	SLAVE_IP=`onevm show ${SLAVE_VM_ID} |grep IP|awk -F'"' '{print $2}'`
	echo "Done. Slave $I VM ID: ${SLAVE_VM_ID} / IP: ${SLAVE_IP}"
	echo "Setting up slave VM $I ..."

	TMP_SETUP_FILE="tmp_slave_setup.sh"
	rm -f $TMP_SETUP_FILE
	echo "#!/bin/bash" >> "$TMP_SETUP_FILE" 
	echo "MASTER_IP=${MASTER_IP}" >> "$TMP_SETUP_FILE"
	echo "SLAVE_NO=$I" >> "$TMP_SETUP_FILE"
	cat "slave_setup.sh" >> "$TMP_SETUP_FILE"

    echo "${SLAVE_IP}       slave${I}" >> "${HOSTS_TMP}"

	echo -n "slave $I (${SLAVE_IP}): " >> "$CLUSTER_ACCESS"
	setupVM "$SLAVE_IP" "$TMP_SETUP_FILE" "$TMP_SETUP_FILE" "$CLUSTER_ACCESS"

	forwardPort "$SLAVE_IP" "22" "SLAVE_OUT_IP" "SLAVE_OUT_PORT"
    HOSTS_PROPAGATION_LIST="${HOSTS_PROPAGATION_LIST};${SLAVE_OUT_IP}:${SLAVE_OUT_PORT}"

	echo "Done."
done;

echo "Configuring hosts file on each node..."
for I in `seq ${SLAVES_COUNT}`; do

    HOSTS_SEND_IP=`echo ${HOSTS_PROPAGATION_LIST}| cut -d";" -f${I} | cut -d":" -f1`
    HOSTS_SEND_PORT=`echo ${HOSTS_PROPAGATION_LIST}| cut -d";" -f${I} | cut -d":" -f2`

	addToHosts "${HOSTS_SEND_IP}" "${HOSTS_SEND_PORT}" "${HOSTS_TMP}"

done;
echo "Done."

echo "rm -f $HOSTS_TMP" >> ${CLEAN_UP}
echo "rm -f $CLUSTER_ACCESS" >> ${CLEAN_UP}

echo "Cleaning up ($OUTTMP_F)"
rm -f $OUTTMP_F expect.log $MASTER_TMP_OUT $SLAVE_TMP_OUT ${HOSTS_TMP}
