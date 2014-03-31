# fuel-nailgun
#
# Version     0.1

FROM centos
MAINTAINER Matthew Mosesohn mmosesohn@mirantis.com

WORKDIR /root

RUN yum install -y yum-utils rubygems
RUN yum-config-manager --add-repo=http://srv11-msk.msk.mirantis.net/fwm/4.1/centos/os/x86_64/ --save
RUN yum-config-manager --add-repo=http://10.20.0.2:8080/centos/fuelweb/x86_64/ --save
RUN sed -i 's/gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/* /etc/yum.conf
RUN yum --quiet install -y puppet python-pip rubygems-openstack ruby-devel-1.8.7.352
RUN yum --quiet install -y nginx python-fuelclient supervisor postgresql-libs python-virtualenv postgresql-devel rsyslog fence-agents gcc gcc-c++ make
RUN mkdir -p /opt/gateone/users/ANONYMOUS/
RUN mkdir -p /var/log/nailgun

ADD etc /etc
ADD var /var
ADD init.pp /root/init.pp

RUN puppet apply -v /root/init.pp

RUN mkdir -p /usr/local/bin
ADD start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8001
VOLUME /opt/nailgun/share/nailgun/static
CMD /usr/local/bin/start.sh
