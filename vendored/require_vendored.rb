$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'puppet/lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'facter/lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'hiera/lib'))

require 'puppet_pal'

# This can be removed when BOLT-66 is implemented, so that puppet_pal
# is the only entry point
require 'puppet'
require 'puppet/node/environment'
require 'puppet/info_service'
