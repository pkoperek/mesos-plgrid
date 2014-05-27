#!/bin/bash

set -eu

FILE="${2}"
DEST="${3}"
grep ssh "${1}" | awk -F":" '{print $2}' | awk -v input="${FILE}" -v output="${DEST}" '{print "scp -P " $3 " " input " " $4 ":" output }'
