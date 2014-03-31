# fuel-rsync
#
# Version     0.1

FROM centos
MAINTAINER Matthew Mosesohn mmosesohn@mirantis.com

WORKDIR /root

RUN yum --quiet install -y yum-utils rubygems
RUN yum --quiet install -y xinetd rsync
ADD etc /etc
EXPOSE 873

CMD /usr/sbin/xinetd -dontfork
