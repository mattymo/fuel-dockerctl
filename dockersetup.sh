#!/bin/bash

#confdir=/etc/dockerctl
confdir="./"
. "$confdir/config"
. "$confdir/functions.sh"

if [ -z "$1" ] || [ "$1" = "help" ]; then
  show_usage
  exit 1
fi

if [ -z "$2" ] || [ "$2" = "all" ]; then
  container="all"
else
  container=$2
fi

if [ "$1" == "build" ]; then
  #Step 1: prepare storage containers
  build_storage_containers
  run_storage_containers

  #Step 2: import app images
  import_images "$COBBLER_IMAGE" "$POSTGRES_IMAGE" "$RABBITMQ_IMAGE" \
  "$RSYNC_IMAGE" "$ASTUTE_IMAGE" "$NAILGUN_IMAGE" "$OSTF_IMAGE" "$NGINX_IMAGE"
  import_images $SOURCE_IMAGES

  #Step 3: Prepare supervisord
  cp $SUPERVISOR_CONF_DIR/* /etc/supervisord.d/

  #Step 3: Launch in order once
  apps="cobbler postgres rabbitmq rsync astute nailgun ostf nginx mcollective"
  for service in $apps; do
    supervisorctl start $service
    sleep 2
  done

  #Step 4: Test deployment TODO(mattymo)
  #run_tests $apps
elif [ "$1" == "start" ]; then
  start_container $container
elif [ "$1" == "stop" ]; then
  stop_container $container
elif [ "$1" == "upgrade" ]; then
  upgrade_container $container
elif [ "$1" == "backup" ]; then
  backup_container $container
else
  show_usage
fi

