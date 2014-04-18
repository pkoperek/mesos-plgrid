#!/bin/bash

set -eu

function getStatus {
	local VM_ID=$1
	local STATUS=`onevm show ${VM_ID}|grep ^STATE|awk -F':' '{print $2}'| tr -d ' '`
	eval "$2='${STATUS}'"
}

function waitUntilRunning {
	local VM_ID=$1
	local VM_STATUS=""
	getStatus ${VM_ID} VM_STATUS
	while [ "$VM_STATUS" != "ACTIVE" ]; do
		echo "Waiting for machine $VM_ID to start ($VM_STATUS)..."
		sleep 5
		getStatus ${VM_ID} VM_STATUS
	done
}

# test
# waitUntilRunning 1338
