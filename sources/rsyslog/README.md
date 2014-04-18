docker-rsyslog
===================

Fuel docker-rsyslog container


```bash
cp /etc/astute.yaml ./

# build
docker build -t fuel/rsyslog ./

# run AFTER storage-puppet and storage-log
docker run \
  -h $(hostname -f) \
  -p 514:514 \
  -p 514:514/udp \
  --volumes-from storage-puppet \
  --volumes-from storage-log \
  -d -t \
  fuel/rsyslog
```
