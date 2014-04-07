FROM busybox
RUN mkdir -p /etc/puppet/modules
ADD etc /etc
VOLUME ["/etc/puppet"]
CMD /bin/echo storage/puppet I am a data-only container for Fuel
