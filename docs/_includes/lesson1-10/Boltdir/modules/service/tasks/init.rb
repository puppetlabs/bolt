#!/opt/puppetlabs/puppet/bin/ruby

require 'puppet'

def start(provider)
  if provider.status == :running
    { status: 'in_sync' }
  else
    provider.start
    { status: 'started' }
  end
end

def stop(provider)
  if provider.status == :stopped
    { status: 'in_sync' }
  else
    provider.stop
    { status: 'stopped' }
  end
end

def restart(provider)
  provider.restart

  { status: 'restarted' }
end

def status(provider)
  { status: provider.status, enabled: provider.enabled? }
end

def enable(provider)
  if provider.enabled?.to_s == 'true'
    { status: 'in_sync' }
  else
    provider.enable
    { status: 'enabled' }
  end
end

def disable(provider)
  if provider.enabled?.to_s == 'true'
    provider.disable
    { status: 'disabled' }
  else
    { status: 'in_sync' }
  end
end

params = JSON.parse(STDIN.read)
service = params['service']
provider = params['provider']
action = params['action']

opts = { name: service }
opts[:provider] = provider if provider

begin
  provider = Puppet::Type.type(:service).new(opts).provider

  result = send(action, provider)
  puts result.to_json
  exit 0
rescue Puppet::Error => e
  puts({ status: 'failure',
         _error: { msg: e.message,
                   kind: "puppet_error",
                   details: {}
                 }
       }.to_json)
  exit 1
end
