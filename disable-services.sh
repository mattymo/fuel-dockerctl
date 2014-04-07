#!/bin/bash

system_services="cobblerd httpd xinetd postgresql rabbitmq-server nginx dnsmasq"
supervisord_services="assassind nailgun naily ostf receiverd"

for system_service in $system_services; do
  chkconfig $system_service off
  service $system_service stop
done
for supervisord_service in $supervisord_services; do
  supervisorctl stop $supervisord_service
done
