#!/bin/bash

#set -o errexit
#set -o nounset
#set -o xtrace

# requires jq be installed on host running this topology script

err() {
    echo "[$(date +'%F %T %Z')]: $@" >&2
    exit 1
}

DN="$1"
MAPPING_FILE="/usr/local/etc/topology/topology_mapping.json"

# check if topology mapping file is present
if [[ ! -s ${MAPPING_FILE} ]]; then
   echo "/default-rack"
   err "topology mapping file does not exist or is not valid"
fi

# check rack topology mapping
RACK=$(jq -r '. | select( (.host_name=='\"$DN\"') or (.ip=='\"$DN\"') ) | .rack_info' ${MAPPING_FILE} | xargs)
if [[ -n "${RACK}" ]]; then
   echo "${RACK}"
else
   echo "/default-rack"
fi


exit 0



#--DONE
