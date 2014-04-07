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
  build_image sources/storage-dump storage/dump
  build_image sources/storage-repo storage/repo
  build_image sources/storage-puppet storage/puppet
}

function run_storage_containers {
  #Run storage containers once
  #Note: storage containers exit, but keep volumes available
  
  #Remove existing ones if they exist
  kill_storage_containers
  docker run -d --name "$DUMP_CNT" storage/dump || true
  docker run -d --name "$REPO_CNT" storage/repo || true
  docker run -d --name "$PUPPET_CNT" storage/puppet || true
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

function start_container {
  if [ -z "$1" ]; then
    echo "Must specify a container name" 1>&2
    exit 1
  fi
  container_name="$1"
  if container_created "$1"; then
    docker start $container_name
  else
    first_run_container "$1" "$container_name"
  fi
}

function stop_container {
  docker stop $CONTAINER_NAMES[$1]
}

function container_lookup {
  return $CNT_PREFIX-$1
}

function container_created {
  return docker ps -a | grep -q $1
}

function first_run_container {
  opts="$CONTAINER_OPTS[${1}]"
  name="$CONTAINER_NAMES[${1}]"
  image="$CONTAINER_IMAGES[${1}]"
  docker run $opts --name=$name $image 
  return 0
}

