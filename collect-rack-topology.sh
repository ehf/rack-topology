#!/bin/bash

# requires curl and jq to be installed
# script collects rack topology information from ambari

#set -o nounset
#set -o xtrace
#set -o errexit


# hold key/value
declare -a CLUSTERS=( 'cluster1' 'cluster2' 'cluster3' 'cluster4' 'cluster5' 'cluster6' )
declare -A AMB_SERVER
AMB_SERVER[cluster1]='https://cluster1-amb.vip.408.systems:8443'
AMB_SERVER[cluster2]='https://cluster2-amb.vip.408.systems:8443'
AMB_SERVER[cluster3]='https://cluster3-amb.vip.408.systems:8443'
AMB_SERVER[cluster4]='https://cluster4-amb.vip.408.systems:8443'
AMB_SERVER[cluster5]='https://cluster5-amb.vip.408.systems:8443'
AMB_SERVER[cluster6]='https://cluster6-amb.vip.408.systems:8443'

# vars
TIMEOUT=60
AMB_API="api/v1/clusters"
NRC="${HOME}/.amb"
TOPOLOGY_PATH="/var/www/html/repo/hadoop/topology"
TOPOLOGY_MAPPING_FILE="${TOPOLOGY_PATH}/topology_mapping.json"
TOPOLOGY_USER="hadoop"
TOPOLOGY_GROUP="hadoop"

# functions
err() {
  echo "[$(date +'%F %T %Z')]: $@" >&2
  exit 1
}

check_amb_status() {
  cluster_arg="$1"
  status=$(curl -sS --netrc-file ${NRC} -k -w "%{http_code}\n" -m ${TIMEOUT} -o /dev/null ${AMB_SERVER[${cluster_arg}]}/${AMB_API}/${cluster_arg})
  [[ ${status} -eq 200 ]] || err "${AMB_SERVER[${cluster_arg}]} not available"
}

create_local_topology_dir() {
  [[ -d ${TOPOLOGY_PATH} ]] || /usr/bin/install --verbose --mode=0755 --owner=${TOPOLOGY_USER} --group=${TOPOLOGY_GROUP} --directory ${TOPOLOGY_PATH}
}

collect_rack_topology() {
  cluster_arg="$1"
  
  create_local_topology_dir
  curl -s --netrc-file ${NRC} \
       -k -H 'X-Requested-By: ambari' \
       -X GET -m ${TIMEOUT} \
       ${AMB_SERVER[${cluster_arg}]}/${AMB_API}/${cluster_arg}/hosts?fields=Hosts/rack_info,Hosts/host_name,Hosts/ip \
       | jq -c '.items[].Hosts | select(.host_name|test("sys[0-9]{1,2}node|.*cl[0-9]{1,2}node"))' \
       > ${TOPOLOGY_MAPPING_FILE}.${cluster_arg}
}

set_rack_topology_permissions() {
  cluster_topology_file="$1"

  chown ${TOPOLOGY_USER}:${TOPOLOGY_GROUP} ${cluster_topology_file}
  chmod 644 ${cluster_topology_file}
}

validate_rack_topology_file() {
  cluster_topology_file="$1"

  # validate topology file
  jq -e . ${cluster_topology_file} >/dev/null 2>&1
  [[ $? -ne 0 ]] && err "${cluster_topology_file} is not valid"
}


# gather topology mapping
for c in "${CLUSTERS[@]}"
do
    check_amb_status ${c}
    collect_rack_topology ${c}
    set_rack_topology_permissions ${TOPOLOGY_MAPPING_FILE}.${c}
    validate_rack_topology_file ${TOPOLOGY_MAPPING_FILE}.${c}
done



exit 0


##--DONE
