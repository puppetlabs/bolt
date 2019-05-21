#!/usr/bin/env bash

openssl req -new -sha256 -nodes -out cert.csr -newkey rsa:2048 -keyout key.pem -config <( cat cert.csr.cnf )

openssl x509 -req -in cert.csr -CA ca.pem -CAkey ca_key.pem -CAcreateserial -out cert.pem -days 999 -sha256 -extfile v3.ext
