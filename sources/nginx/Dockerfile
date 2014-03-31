#Should be linked to the following
# -volumes-from nailgun
# -volumes-from storage-dump
# --volume "/etc/fuel:/etc/fuel"

##Deprecated start
#
##Should be linked to the following containers:
##fuel/nailgun (port 8000)
##fuel/naily (volume /var/www/dump)
##fuel/ostf (port 8777)
#FROM ubuntu:12.04
#MAINTAINER Ben Firshman "ben@orchardup.com"
#RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
#RUN apt-get update
#RUN apt-get -y install nginx
#
##RUN echo "daemon off;" >> /etc/nginx/nginx.conf
##RUN mkdir /etc/nginx/ssl
##ADD default /etc/nginx/sites-available/default
##ADD default-ssl /etc/nginx/sites-available/default-ssl
#
##Deprecated end
FROM centos
MAINTAINER Matthew Mosesohn mmosesohn@mirantis.com

WORKDIR /root

RUN yum --quiet install -y yum-utils
RUN yum-config-manager --add-repo=http://srv11-msk.msk.mirantis.net/fwm/4.1/centos/os/x86_64/ --save
RUN yum-config-manager --add-repo=http://10.20.0.2:8080/centos/fuelweb/x86_64/ --save
RUN sed -i 's/gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/* /etc/yum.conf
RUN yum --quiet -y install nginx puppet

ADD etc /etc
ADD site.pp /root/site.pp
RUN puppet apply -v site.pp

RUN mkdir -p /usr/local/bin
ADD start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8000
EXPOSE 8080
CMD ["/usr/local/bin/start.sh"]

