# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_transport(
  name: 'fake',
  desc: 'This device just modifies a file on the on controller',
  features: [],
  connection_info: {
    path: {
      type: 'String',
      desc: 'The path the devices file'
    }
  }
)
