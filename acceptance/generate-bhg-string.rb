#!/usr/bin/ruby

# frozen_string_literal: true

n = ENV['BOLT_NODES'].split(',')
n_new = []
n.each do |node|
  roles = []
  roles << if /win/ =~ node
             'winrm'
           else
             'ssh'
           end
  node = node + roles.join(',') + '.{type=aio}'
  n_new << node
end
ENV['BOLT_CONTROLLER'] = ENV['BOLT_CONTROLLER'] + 'bolt,ssh'
ENV['BOLT_NODES'] = n_new.join('-')
