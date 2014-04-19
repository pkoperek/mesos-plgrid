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
MEMORY = 512

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

# test
# waitUntilRunning 1338
