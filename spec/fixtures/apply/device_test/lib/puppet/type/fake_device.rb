require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'fake_device',
  docs: 'fake device for testing puppet-device',
  attributes: {
    ensure: {
      type:    'Enum[present, absent]',
      desc:    'Whether this apt key should be present or absent on the target system.',
      default: 'present',
    },
    name: {
      type:      'String',
      desc:      'the path the key to modify',
      behaviour: :namevar,
    },
    content: {
      type: 'Data',
      desc: 'The value to set'
    },
    merge: {
      type: 'Boolean',
      desc: 'whether to merge the value',
      default: false,
      behaviour: :parameter
    }
  },
  features: ['remote_resource'],
)
