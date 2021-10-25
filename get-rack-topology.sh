#!/bin/bash

# requires curl, jq and sha256sum to be installed
# script collects rack topology information from ambari

#set -o nounset
#set -o errexit
set -o xtrace


# vars
declare -a CLUSTERS=( 'cluster1' 'cluster2' )
TIMEOUT=60
TOPOLOGY_PATH="/usr/local/etc/topology"
TOPOLOGY_JSON="topology_mapping.json"
TOPOLOGY_MAPPING_FILE="${TOPOLOGY_PATH}/${TOPOLOGY_JSON}"
REPO="http://repo.vip.408.systems"
TOPOLOGY_REPO_PATH="repo/hadoop/topology"
TOPOLOGY_REPO_FILE="${REPO}/${TOPOLOGY_REPO_PATH}/${TOPOLOGY_JSON}"
TOPOLOGY_USER="hdfs"
TOPOLOGY_GROUP="hadoop"

# functions
err() {
  echo "[$(date +'%F %T %Z')]: $@" >&2
  exit 1
}

check_repo_status() {
  status=$(curl -sS -k -w "%{http_code}\n" -m ${TIMEOUT} -o /dev/null ${REPO}/repo/status.txt)
  [[ ${status} -eq 200 ]] || err "${REPO} not available"
}

generate_sha() {
  file_arg="$1"

  sha256sum ${file_arg} > ${file_arg}.SHA256SUM
}

download_cluster_topology_file() {
  cluster_arg="$1"

  curl -s -X GET -m ${TIMEOUT} ${TOPOLOGY_REPO_FILE}.${cluster_arg} > ${TOPOLOGY_MAPPING_FILE}.${cluster_arg}
  generate_sha ${TOPOLOGY_MAPPING_FILE}.${cluster_arg}
}

create_local_topology_dir() {
  [[ -d ${TOPOLOGY_PATH} ]] || /usr/bin/install --verbose --mode=0755 --owner=${TOPOLOGY_USER} --group=${TOPOLOGY_GROUP} --directory ${TOPOLOGY_PATH}
}

get_rack_topology() {
  cluster_arg="$1"

  # download rack topology file if cluster topology has been updated
  create_local_topology_dir
  file_sha=$(sha256sum <(curl -sL ${TOPOLOGY_REPO_FILE}.${cluster_arg} 2>/dev/null) | awk '{print $1}')
  echo "${file_sha} ${TOPOLOGY_MAPPING_FILE}.${cluster_arg}" | sha256sum --check --status
  [[ $? -ne 0 ]] && download_cluster_topology_file ${cluster_arg}
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

collect_rack_topology_files() {
  for i in "${CLUSTERS[@]}"
  do
     all_topology_files+=("${TOPOLOGY_MAPPING_FILE}.${i}")
  done
}

generate_topology_file() {
  paste -s -d '\n' "${all_topology_files[@]}" > ${TOPOLOGY_MAPPING_FILE}
  generate_sha ${TOPOLOGY_MAPPING_FILE}
}

merge_rack_topology_files() {
  # if existing rack topology file does not pass check,
  # then merge all cluster topology files and create new rack topology file

  file_sha=$(sha256sum <(paste -s -d '\n' "${all_topology_files[@]}" 2>/dev/null) | awk '{print $1}')
  echo "${file_sha} ${TOPOLOGY_MAPPING_FILE}" | sha256sum --check --status
  [[ $? -ne 0 ]] && generate_topology_file
}


# get rack topology files
for c in "${CLUSTERS[@]}"
do
    check_repo_status
    get_rack_topology ${c}
    set_rack_topology_permissions ${TOPOLOGY_MAPPING_FILE}.${c}
    validate_rack_topology_file ${TOPOLOGY_MAPPING_FILE}.${c}
done

# merge topology files
collect_rack_topology_files
merge_rack_topology_files
validate_rack_topology_file ${TOPOLOGY_MAPPING_FILE}
set_rack_topology_permissions ${TOPOLOGY_MAPPING_FILE}
set_rack_topology_permissions ${TOPOLOGY_MAPPING_FILE}.SHA256SUM


exit 0


##--DONE
