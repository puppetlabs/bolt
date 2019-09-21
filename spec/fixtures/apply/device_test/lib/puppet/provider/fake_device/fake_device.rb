# frozen_string_literal: true

require 'puppet/resource_api'
require 'puppet/resource_api/simple_provider'

# rubocop:disable Style/ClassAndModuleChildren
class Puppet::Provider::FakeDevice::FakeDevice < Puppet::ResourceApi::SimpleProvider
  # rubocop:enable Style/ClassAndModuleChildren
  def get(context)
    context.transport.get
  end

  def update(context, name, should)
    context.transport.set(name, should[:content])
  end

  def create(context, name, should)
    update(context, name, should)
  end

  def delete(context, name)
    context.transport.delete(name)
  end
end
