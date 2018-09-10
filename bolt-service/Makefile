all: image

deps:
	@go get github.com/square/certstrap/...

# TODO write targets for the actual files that get created
certs: deps
	@echo "Generating Test Certs"
	@rm -rf certs
	@mkdir certs
	@certstrap --depot-path certs init --common-name "bolt-server-ca" --passphrase ""
	@certstrap --depot-path certs request-cert --domain localhost --passphrase ""
	@certstrap --depot-path certs sign --CA "bolt-server-ca" localhost
	@certstrap --depot-path certs request-cert --ip 127.0.0.1 --passphrase ""
	@certstrap --depot-path certs sign --CA "bolt-server-ca" 127.0.0.1


image: certs
	@echo "Building Bolt Service Image"
	@docker build ${DOCKER_OPTS} --rm -t puppet/bolt-service:latest -f Dockerfile .


run:
	@echo "Starting Bolt Service on localhost:8144"
	@docker run -it --rm -p 8144:8144 --name "bolt-service" puppet/bolt-service:latest
