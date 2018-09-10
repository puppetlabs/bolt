# Bolt Service

This project creates a docker image for the bolt service.   
Currently the service generates test certificates that are copied into the
image.   For production use these should be overwritten with your own certs,
see details below.


## Building
Run make to build the project, this generates test certs and creates a docker
image called puppet/bolt-service:latest

```
make
```

## Running the service
You can run the service by creating a new container.  N.B by default the Service
listens on port 8144, so you must ensure it is exposed.
```
docker run -it --rm -p 8144:8144 --name "bolt-service" puppet/bolt-service:latest
```

Alternatively you can use the run target in the makefile
```
make run
```

## Testing the Service
You can use curl to test the service.  A helper script with an example request
can be found in the test folder.   This executes a simple ruby script that executes
whoami

To run the test do the following:

1) Create a linux machine running SSH

2) Edit test/request.json and set the host, username and password fields

3) Run test/test.sh
```
test/test.sh
```

The output should look like this:
```
{"node":"cfq72ae44c7ac1i.delivery.puppetlabs.net","status":"success","result":{"_output":"root\n"}}
```

## Custom Certs
You can overwrite the certs being used by mounting a volume with your certs when
starting the container. i.e.

```
docker run -it --rm -p 8144:8144 \
  -v /Users/me/bolt-service/certs:/etc/puppetlabs/bolt-server/ssl/ \
  --name "bolt-service" puppet/bolt-service:latest
```

N.B This assumes you have named your certs localhost.crt, localhost.key and
bolt-server-ca.crt.


If you use different names you will need to override the SSL config by creating
a local file and mounting that into the container i.e.

/Users/me/bolt-service/conf.d/bolt-server.conf
```
bolt-server: {
     ssl-cert: "/etc/puppetlabs/bolt-server/ssl/custom_cert.crt"
     ssl-key: "/etc/puppetlabs/bolt-server/ssl/custom_key.key"
     ssl-ca-cert: "/etc/puppetlabs/bolt-server/ssl/custom-ca.crt"
}
 ```

 ```
 docker run -it --rm -p 8144:8144 \
   -v /Users/me/bolt-service/certs:/etc/puppetlabs/bolt-server/ssl/ \
   -v /Users/me/bolt-service/conf.d/:/etc/puppetlabs/bolt-server/conf.d/ \
   --name "bolt-service" puppet/bolt-service:latest
 ```
