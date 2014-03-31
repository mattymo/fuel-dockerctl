# fuel-nailgun
#
# Version     0.1

FROM centos
MAINTAINER Matthew Mosesohn mmosesohn@mirantis.com

WORKDIR /root

RUN yum --quiet install -y yum-utils
RUN yum-config-manager --add-repo=http://srv11-msk.msk.mirantis.net/fwm/4.1/centos/os/x86_64/ --save
#RUN yum-config-manager --add-repo=http://10.20.0.2:8080/centos/fuelweb/x86_64/ --save
RUN yum-config-manager --add-repo=http://osci-obs.vm.mirantis.net:82/centos-fuel-4.0.1-eggs/centos/ --save
RUN rm -f /etc/yum.repos.d/CentOS*
RUN sed -i 's/gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/* /etc/yum.conf
RUN yum --quiet install -y puppet python-pip rubygems-openstack ruby-devel-1.8.7.352
RUN yum --quiet install -y nginx python-fuelclient supervisor postgresql-libs python-virtualenv postgresql-devel rsyslog fence-agents gcc gcc-c++ make

ADD etc /etc
ADD var /var

ADD site.pp /root/site.pp
RUN puppet apply -d -v /root/site.pp

RUN mkdir -p /usr/local/bin
ADD start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh
EXPOSE 8777
CMD /usr/local/bin/start.sh
