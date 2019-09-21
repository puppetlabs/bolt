#!/bin/sh

set -e

CERTNAME=pdb /ssl-setup.sh

exec java $PUPPETDB_JAVA_ARGS -cp /puppetdb.jar \
    clojure.main -m puppetlabs.puppetdb.core "$@" \
-c /etc/puppetlabs/puppetdb/conf.d/
