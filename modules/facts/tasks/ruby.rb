#!/usr/bin/env ruby
# frozen_string_literal: true

def facter_executable
  if ENV.key? 'Path'
    ENV['Path'].split(';').each do |p|
      if p =~ /Puppet\\bin\\?$/
        return File.join(p, 'facter')
      end
    end
    'C:\Program Files\Puppet Labs\Puppet\bin\facter'
  else
    '/opt/puppetlabs/puppet/bin/facter'
  end
end

# Delegate to facter
exec(facter_executable, '-p', '--json')
