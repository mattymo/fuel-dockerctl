#!/bin/bash

function show_usage {
  echo "$0 usage:"
  echo "  $0 command"
  echo
  echo "Available commands: (Note: work in progress)"
  echo "  help: show this message"
  echo "  build: create all Docker containers"
  echo "  start: start all Docker containers"
  echo "  restart: restart one or more Docker containers"
  echo "  stop: stop one or more Docker containers"
  echo "  upgrade: upgrade deployment"
}
function debug {
  if $DEBUG; then
    echo $@
  fi
}
function build_image {
  docker build -t $2 $1
}

function build_storage_containers {
  build_image $SOURCE_DIR/storage-dump storage/dump
  build_image $SOURCE_DIR/storage-repo storage/repo
  build_image $SOURCE_DIR/storage-puppet storage/puppet
  build_image $SOURCE_DIR/storage-log storage/log
}

function run_storage_containers {
  #Run storage containers once
  #Note: storage containers exit, but keep volumes available
  
  #Remove existing ones if they exist
  kill_storage_containers
  docker run -d --name "$DUMP_CNT" storage/dump || true
  docker run -d -v /var/www/nailgun:/var/www/nailgun --name "$REPO_CNT" storage/repo || true
  docker run -d -v /etc/puppet:/etc/puppet --name "$PUPPET_CNT" storage/puppet || true
  docker run -d --name "$LOG_CNT" storage/log || true
}

function kill_storage_containers {
  containers=$(docker ps -a | egrep "($DUMP_CNT|$REPO_CNT|$PUPPET_CNT)" | cut -d' ' -f1)
  if [ -n "$containers" ]; then
    docker rm $containers || true
  fi
}
function import_images {
  #Imports images with xz, gzip, or simple tar format
  for image_archive in $@; do
    debug "Importing $image_archive"
    image="$(echo $image_archive | cut -d. -f1)"
    if egrep -q "gz\$" <<< "$image_archive"; then
      zcat "$image_archive" | docker load
    elif egrep -q "xz\$" <<< "$image_archive"; then
      #xz -dkc "$image_archive" | docker load - "${IMAGE_PREFIX}/${image}"
      xz -dkc "$image_archive" | docker load
    else
      #try to just import
      cat "$image_archive" | docker load
    fi
  done
}

function export_containers {
  #--trim option removes $CNT_PREFIX from container name when exporting
  if [[ "$1" == "--trim" ]]; then
    trim=true
    shift
  else
    trim=false
  fi

  for image in $@; do
    [ $trim ] && image=$(sed "s/${CNT_PREFIX}//" <<< "$image")
    docker export $1 | gzip -c > "${image}.tar.gz"
  done
}

function commit_container {
  container_name="${CONTAINER_NAMES[$1]}"
  image="$IMAGE_PREFIX/$1"
  docker commit $container_name $image
}
function start_container {
  if [ -z "$1" ]; then
    echo "Must specify a container name" 1>&2
    exit 1
  fi
  image_name="$IMAGE_PREFIX/$1"
  container_name=${CONTAINER_NAMES[$1]}
  if container_created "$container_name"; then
    if is_running "$container_name"; then
      echo "$container_name is already running."
    else
      docker start $container_name
    fi
    if [ "$2" = "--attach" ]; then 
      attach_container $container_name
    fi
  else
    first_run_container "$1" $2
  fi

}

function attach_container {
  echo "Attaching to container $container_name..."
  docker attach $1
}
function stop_container {
  if $container == 'all'; then
    docker stop $CONTAINER_NAMES[$1]
  else 
    for container in $@; do
      docker stop ${CONTAINER_NAMES[$container]}
    done
  fi
}

function destroy_container {
  if $container == 'all'; then
    stop_container ${CONTAINER_NAMES[@]}
    docker rm ${CONTAINER_NAMES[@]}
  else
    for container in $@; do
      docker rm ${CONTAINER_NAMES[$container]}
    done
  fi
}


function restart_container {
  stop_container $1
  start_container $1
}

function container_lookup {
  return $CNT_PREFIX-$1
}

function container_created {
  docker ps -a | grep -q $1
  return $?
}
function is_running {
  docker ps | grep -q $1
  return $?
}
function first_run_container {

  opts="${CONTAINER_OPTIONS[$1]}"
  container_name="${CONTAINER_NAMES[$1]}"
  image="$IMAGE_PREFIX/$1"
  if ! is_running $container_name; then
      pre_hooks $1
      docker run $opts $BACKGROUND --name=$container_name $image
      post_hooks $1
  else
      echo "$container_name is already running."
  fi
  if [ "$2" = "--attach" ]; then 
      attach_container $container_name
  fi
  return 0
}

function pre_hooks {
  return 0
}

function post_hooks {
  case $1 in
    cobbler)   setup_dhcrelay_for_cobbler
               ;;
    *)         ;;
  esac
}

function setup_dhcrelay_for_cobbler {
  if ! is_running "cobbler"; then
    echo "ERROR: Cobbler container isn't running." 1>&2
    exit 1
  fi
  cobbler_ip=$(docker inspect -format='{{.NetworkSettings.IPAddress}}' ${CONTAINER_NAME["cobbler"]})
  admin_interface=$(grep interface: $ASTUTE_YAML | cut -d':' -f2 | tr -d ' ')
  cat > /etc/sysconfig/dhcrelay << EOF
# Command line options here
DHCRELAYARGS=""
# DHCPv4 only
INTERFACES="$admin_interface docker0"
# DHCPv4 only
DHCPSERVERS="$cobbler_ip"
EOF
  rpm -q dhcp 2>&1 > /dev/null || yum --quiet -y install dhcp
  chkconfig dhcrelay on
  service dhcrelay restart
}
