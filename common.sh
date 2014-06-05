#!/bin/bash

set -eu

function getStatus {
	local VM_ID=$1
	local STATUS=`onevm show ${VM_ID}|grep ^STATE|awk -F':' '{print $2}'| tr -d ' '`
	eval "$2='${STATUS}'"
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

	SCP="scp -oBatchMode=yes -oStrictHostKeyChecking=no -P ${PORT} ${FILE} root@${IP}:${FILE}"
         
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
	local SETUP_IP="$3"
	local FILE="$4"
	local CLUSTER_ACCESS="$5"

	echo -n "Forwarding ssh..."
	forwardSsh "$SETUP_IP" "SETUP_IP_OUT" "SETUP_PORT_OUT"
	echo "Done."
 
	echo "Access forwarded to: $SETUP_IP_OUT $SETUP_PORT_OUT (\"ssh -p "$SETUP_PORT_OUT" root@"$SETUP_IP_OUT"\")"
	if [ -n "$CLUSTER_ACCESS" ]; then
		echo "ssh -p $SETUP_PORT_OUT root@$SETUP_IP_OUT" >> "${CLUSTER_ACCESS}"
	fi

	echo "Copying script ($FILE)..."
	uploadFile "${SETUP_IP_OUT}" "${SETUP_PORT_OUT}" "${FILE}"
	echo "Done."
 
	echo -n "Executing script ($FILE)..."
	ssh -oStrictHostKeyChecking=no -p "$SETUP_PORT_OUT" root@"${SETUP_IP_OUT}" "chmod +x ${FILE} && ./${FILE}" >& execution.log
	echo "Done."
}

# test
# waitUntilRunning 1338
