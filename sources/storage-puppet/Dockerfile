#run with -v /etc/puppet:/puppet
FROM busybox
RUN mkdir -p /etc/puppet/modules /puppet
VOLUME ["/etc/puppet"]
CMD /bin/echo storage/puppet I am a data-only container for Fuel && ln -s /puppet /etc/puppet
