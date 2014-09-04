#!/bin/bash

set -eu

function getStatus {
	local VM_ID=$1
	local STATUS=`onevm show ${VM_ID}|grep ^STATE|awk -F':' '{print $2}'| tr -d ' '`
	eval "$2='${STATUS}'"
}

function rebootVM {
	set +eu
	local VM_IP="$1"
	local VM_PORT="$2"
	
	REBOOT_CMD="ssh -oStrictHostKeyChecking=no -oBatchMode=yes -p ${VM_PORT} root@${VM_IP} reboot"
	${REBOOT_CMD}
	while [ "$?" != "0" ]; do
		echo "Not rebooted - attempt to reboot in 3 ..." 
                sleep 3
		${REBOOT_CMD}
        done

	MONITOR="ssh -oBatchMode=yes -oStrictHostKeyChecking=no -p ${VM_PORT} root@${VM_IP} ps aux|grep java|grep -v grep|wc -l"

	echo "Waiting for ${VM_IP} ${VM_PORT} to start..."
	sleep 5

	RES=`$MONITOR`
        while [ "${RES}" == "0" ]; do
                echo "Not started yet - waiting ..." 
                sleep 3
                RES=`$MONITOR`
        done
	set -eu
}

function waitUntilState {
	local VM_ID=$1
	local VM_STATUS=""
	local VM_STATUS_TO_WAIT=$2
	getStatus ${VM_ID} VM_STATUS
	while [ "$VM_STATUS" != "$VM_STATUS_TO_WAIT" ]; do
		echo "Waiting for machine $VM_ID to get to $VM_STATUS_TO_WAIT ($VM_STATUS)..."
		sleep 5
		getStatus ${VM_ID} VM_STATUS
	done
}

function addToHosts {
    local SEND_IP="$1"
    local SEND_PORT="$2"
    local FILENAME="$3"

    local BASENAME=`basename ${FILENAME}`
    
    uploadFile "${SEND_IP}" "${SEND_PORT}" "${FILENAME}"

    ssh -oStrictHostKeyChecking=no -p "${SEND_PORT}" root@"${SEND_IP}" "cat /root/${BASENAME} >> /etc/hosts"
}

function generateTemplate {
local TEMPLATE_NAME="$1"
local IMGID="$2"
local NETID="$3"
local HNAME="$4"
local SSHKEY="$5"
local OUTPUT_FILE="$6"

(
cat <<_EOF_
NAME = "$TEMPLATE_NAME" 
CPU    = 0.2
MEMORY = 2048

DISK = [ IMAGE_ID  = $IMGID ]

NIC    = [ NETWORK_ID = $NETID ]

OS = [ arch = "x86_64" ]

GRAPHICS = [
  type    = "vnc"
]

CONTEXT = [
  hostname = "$HNAME",
  ssh_key = "$SSHKEY"
]
_EOF_
) > $OUTPUT_FILE
}

function uploadFile {
	set +eu
	local IP="$1"
	local PORT="$2"
	local FILE="$3"

	SCP="scp -oBatchMode=yes -oStrictHostKeyChecking=no -r -P ${PORT} ${FILE} root@${IP}:"
         
	$SCP
	while [ "$?" != "0" ]; do
        	echo "Retrying ..." 
        	sleep 3
        	$SCP
	done
	set -eu
}

function forwardPort {
	local IP="$1"
	local IP_RETVAL="$3"
	local PORT_RETVAL="$4"
	local PORT_TO_FORWARD="$2"

	IPPORT_LINES=`oneport -a $IP -p $PORT_TO_FORWARD -A`
 
	PORT_OUT=`echo "$IPPORT_LINES"|grep "Public port:"| awk -F":" '{print $2}'| tr -d ' '`
	IP_OUT=`echo "$IPPORT_LINES"|grep "Public IP:"|awk -F":" '{print $2}'| tr -d ' '`

    if [ -n "$CLEAN_UP" ]; then
        echo "oneport -D -a $IP -p $PORT_OUT" >> "${CLEAN_UP}" 
    fi

	eval "$IP_RETVAL=$IP_OUT"
	eval "$PORT_RETVAL=$PORT_OUT"
}

function forwardSsh {
	forwardPort "$1" "22" "$2" "$3"
}

function setupVM {
	local SETUP_IP="$1"
	local UPLOAD_FILES="$2"
    local SETUP_SCRIPT="$3"
	local CLUSTER_ACCESS="$4"

	echo -n "Forwarding ssh..."
	forwardSsh "$SETUP_IP" "SETUP_IP_OUT" "SETUP_PORT_OUT"
	echo "Done."
 
	echo "Access forwarded to: $SETUP_IP_OUT $SETUP_PORT_OUT (\"ssh -p "$SETUP_PORT_OUT" root@"$SETUP_IP_OUT"\")"
	if [ -n "$CLUSTER_ACCESS" ]; then
		echo "ssh -p $SETUP_PORT_OUT root@$SETUP_IP_OUT" >> "${CLUSTER_ACCESS}"
	fi

	echo "Copying scripts ($UPLOAD_FILES)..."
	uploadFile "${SETUP_IP_OUT}" "${SETUP_PORT_OUT}" "${UPLOAD_FILES}"
	echo "Done."
 
	echo -n "Executing script ($SETUP_SCRIPT)..."
	ssh -oStrictHostKeyChecking=no -p "$SETUP_PORT_OUT" root@"${SETUP_IP_OUT}" "chmod +x ${SETUP_SCRIPT} && ./${SETUP_SCRIPT}" >& execution.log
	echo "Done."
}

# test
# waitUntilRunning 1338
