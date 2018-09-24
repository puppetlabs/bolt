# Bolt Service

Bolt service is a systemd service that runs a puma webserver implementing the
[bolt-server API](../developer-docs/bolt_server.md). This project creates a
docker image for the bolt service.  

## Generating Certs

The first thing to do is generate certificates for the bolt service to use

```
make certs
```

## Build the Image

This uses [Docker]() to build the image used to create the container

```
docker build --rm -t puppet/bolt-server:latest
```

## Run the Service

You can run the service by creating a new container based on the image you
just built. **N.B** by default the Service listens on port 62658, so you must
ensure it is exposed.
```
docker run -it --rm -p 62658:62658 --name "bolt-service" puppet/bolt-service:latest
```
## Testing the Service
You can use curl to test the service. A helper script with an example request
can be found in the test directory. This executes a simple ruby script that runs `whoami`.

To run the test do the following:

1. Edit `resources/request.json` and set the host, username and password fields
2. Run 
```
curl -X POST -H "Content-Type: application/json" \
  -d @resources/request.json \
  -E certs/127.0.0.1.crt \
  --key certs/127.0.0.1 \
  --cacert certs/bolt-server-ca.crt \
  https://localhost:62658/ssh/run_task
```

The output should look like this:
```
{"node":"cfq72ae44c7ac1i.delivery.puppetlabs.net","status":"success","result":{"_output":"root\n"}}
```

## Custom Certs
You can overwrite the certs being used by mounting a volume with your certs when
starting the container. For example:

```
docker run -it --rm -p 62658:62658 \
  -v certs:/etc/puppetlabs/bolt-server/ssl/ \
  --name "bolt-service" puppet/bolt-service:latest
```

**N.B** This assumes you have named your certs localhost.crt, localhost.key
and bolt-server-ca.crt. If you use different names you will need to modify
the [SSL config](resources/bolt-server.conf)

```
bolt-server: {
     ssl-cert: "/etc/puppetlabs/bolt-server/ssl/custom_cert.crt"
     ssl-key: "/etc/puppetlabs/bolt-server/ssl/custom_key.key"
     ssl-ca-cert: "/etc/puppetlabs/bolt-server/ssl/custom-ca.crt"
}
```

Then rebuild the container to contain your new config file

```
docker build $DOCKER_OPTS --rm -t puppet/bolt-server:latest
docker run -it --rm -p 62658:62658 \
 -v certs:/etc/puppetlabs/bolt-server/ssl/ \
 --name "bolt-service" puppet/bolt-service:latest
```
