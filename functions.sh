#!/bin/bash

function show_usage {
  echo "Usage:"
  echo "  $0 command"
  echo
  echo "Available commands: (Note: work in progress)"
  echo "  help: show this message"
  echo "  build: create all Docker containers"
  echo "  start: start all Docker containers"
  echo "  restart: restart one or more Docker containers"
  echo "  stop: stop one or more Docker containers"
  echo "  shell: start a shell or run a command in a Docker container"
  echo "  upgrade: upgrade deployment"
  echo "  destroy: destroy one or more containers"
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
  #kill_storage_containers
  docker run -d ${CONTAINER_VOLUMES[$DUMP_CNT]} --name "$DUMP_CNT" storage/dump || true
  docker run -d ${CONTAINER_VOLUMES[$REPO_CNT]} --name "$REPO_CNT" storage/repo || true
  docker run -d ${CONTAINER_VOLUMES[$PUPPET_CNT]} --name "$PUPPET_CNT" storage/puppet || true
  #docker run -d ${CONTAINER_VOLUMES[$LOG_CNT]} --name "$LOG_CNT" storage/log || true
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
    if [ ! -f $image_archive ]; then
      echo "Warning: $image_archive does not exist. Skipping..."
      continue
    fi
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
      if is_ghost "$container_name"; then
        restart_container $1
      else
        echo "$container_name is already running."
      fi
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

function shell_container {
  container_name=${CONTAINER_NAMES[$1]}
  if ! is_running $container_name; then
    echo "Container $1 is not running. Cannot attach." 1>&2
  fi
  id=$(docker inspect -f='{{.ID}}' ${CONTAINER_NAMES[$1]})
  if [ -z $id ]; then
     echo "Could not get docker ID for $container. Is it running?" 1>&2
     return 1
  fi
  if [ -z $2 ]; then
    command="/bin/bash"
  else
    shift
    command="$@"
  fi
  lxc-attach --name $id $@
}

function stop_container {
  if [[ "$1" == 'all' ]]; then
    docker stop ${CONTAINER_NAMES[$1]}
  else
    for container in $@; do
      echo "Stopping $container..."
      docker stop ${CONTAINER_NAMES[$container]}
    done
  fi
}

function destroy_container {
  if [[ "$1" == 'all' ]]; then
    stop_container all
    docker rm ${CONTAINER_NAMES[@]}
  else
    for container in $@; do
      stop_container $container
      docker rm ${CONTAINER_NAMES[$container]}
      if [ $? -ne 0 ]; then
        #This happens because devicemapper glitched
        #Try to unmount all devicemapper mounts manually and try again
        echo "Destruction of container $container failed. Trying workaround..."
        id=$(docker inspect -f='{{.ID}}' ${CONTAINER_NAMES[$container]})
        if [ -z $id ]; then
          echo "Could not get docker ID for $container" 1>&2
          return 1
        fi
        umount -l $(grep "$id" /proc/mounts | awk '{print $2}' | sort -r)
        #Try to delete again
        docker rm ${CONTAINER_NAMES[$container]}
        if [ $? -ne 0 ];then
          echo "Workaround failed. Unable to destroy container $container."
        fi
      fi
    done
  fi
}

function logs {
  docker logs ${CONTAINER_NAMES[$1]}
}



function restart_container {
  docker restart ${CONTAINER_NAMES[$1]}
}

function container_lookup {
  echo ${CONTAINER_NAMES[$1]}
}

function container_created {
  docker ps -a | grep -q $1
  return $?
}
function is_ghost {
  LANG=C docker ps | grep $1 | grep -q Ghost
  return $?
}
function is_running {
  docker ps | grep -q $1
  return $?
}
function first_run_container {

  opts="${CONTAINER_OPTIONS[$1]} ${CONTAINER_VOLUMES[$1]}"
  container_name="${CONTAINER_NAMES[$1]}"
  image="$IMAGE_PREFIX/$1_$VERSION"
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
    rsyslog)   remangle_syslog
               ;;
    nginx)     remangle_nginx
               ;;
    *)         ;;
  esac
}
function remangle_port {
  proto=$1
  port=$2
  admin_interface=$(grep interface: $ASTUTE_YAML | cut -d':' -f2 | tr -d ' ')
  #Use facter and ipcalc to get admin network CIDR
  admin_net_ip=$(facter "ipaddress_${admin_interface}")
  admin_net_netmask=$(facter "netmask_$admin_interface")
  eval $(ipcalc -np "$admin_net_ip" "$admin_net_netmask")
  iptables -t nat -I POSTROUTING 1 -s "$NETWORK/$PREFIX" -p $proto -m $proto --dport $port -j ACCEPT
  iptables -I FORWARD -i $admin_interface -o docker0  -m state --state NEW -p $proto  -m $proto --dport $port -j ACCEPT
}

function remangle_nginx {
  #Necessary to forward packets to rsyslog with correct src ip
  remangle_port tcp 8000
  remangle_port tcp 8080
}

function remangle_syslog {
  #Necessary to forward packets to rsyslog with correct src ip
  remangle_port tcp 514
  remangle_port udp 514
}

function setup_dhcrelay_for_cobbler {
  if ! is_running "cobbler"; then
    echo "ERROR: Cobbler container isn't running." 1>&2
    exit 1
  fi
  cobbler_ip=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' ${CONTAINER_NAMES["cobbler"]})
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

function allow_all_docker_traffic {
  iptables -A POSTROUTING -t nat  -o docker0  -j MASQUERADE
}
