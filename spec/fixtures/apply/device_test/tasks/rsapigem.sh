#!/bin/bash

cd /tmp

git clone -b pup-9747-bolt-attribute-filtering https://github.com/DavidS/puppet-resource_api.git

cd puppet-resource_api

/opt/puppetlabs/puppet/bin/gem build puppet-resource_api

/opt/puppetlabs/puppet/bin/gem install puppet-resource_api*gem
