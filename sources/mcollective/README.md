docker-mcollectived
===================

Fuel docker-mcollectived container


```bash
# build
docker build -t fuel/mcollectived ./

# run AFTER storage-puppet, storage-log and docker-rabbitmq
docker run \
  -h $(hostname -f) \
  --volume=/etc:/etc/fuel:ro \
  --volumes-from storage-puppet \
  --volumes-from storage-log \
  -d -t \
  fuel/mcollectived
```
