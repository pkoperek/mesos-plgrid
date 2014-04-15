#!/bin/bash

set +eu

DRY_RUN="$1"

echo "DRY_RUN = ${DRY_RUN}" 

TS=`date +%s`
OUTTMP_F="/tmp/onetmptempl.$USER.$TS"

IMGID=8
NETID=0
HNAME=master

if [ -z "$HNAME" ]; then
  HNAME="plgcloud"
fi

if [ ! -f ~/.ssh/id_rsa.pub ]
then
  echo 'Error - could not found generated key'
  exit
fi

SSHKEY=`cat ~/.ssh/id_rsa.pub`

echo -n 'Generating template...'

(
cat <<_EOF_
NAME = "AUTO$IMGID-$USER-$TS" 
CPU    = 0.2
MEMORY = 512

DISK = [ IMAGE_ID  = $IMGID ]

NIC    = [ NETWORK_ID = $NETID ]

OS = [ arch = "x86_64" ]

GRAPHICS = [
  type    = "vnc"
]

CONTEXT = [
  user_data = "MASTER",
  hostname = "$HNAME",
  ssh_key = "$SSHKEY"
]
_EOF_
) > $OUTTMP_F

echo Done.

if [ -n "${DRY_RUN}" ]; then
	echo "Template contents:"
	cat $OUTTMP_F
else 
	echo 'Uploading template'
	TEMPLATE_ID=`onetemplate create $OUTTMP_F | grep ID | awk -F':' '{print $2}'|tr -d ' '`
	echo "Uploaded ${TEMPLATE_ID}"
	VM_ID=`onetemplate instantiate ${TEMPLATE_ID} | grep ID | awk -F':' '{print $2}'|tr -d ' '`
	onevm show ${VM_ID} | grep IP
fi

echo 'Cleaning up'
rm -f $OUTTMP_F
