#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'json'
require 'puppet'

def apply_resource(type, title, params)
  result = {
    type: type,
    title: title,
    changed: false
  }

  resource = Puppet::Resource.new(type, title, parameters: params)

  # Configure the indirection to manage the resource locally and not cache it anywhere else
  Puppet::Resource.indirection.terminus_class = :ral
  Puppet::Resource.indirection.cache_class = nil

  _saved_resource, report = Puppet::Resource.indirection.save(resource)

  # This step is necessary to compute the report "status"
  report.finalize_report

  resource_status = report.resource_statuses.values.first

  # Non-existent resource types and strange built-in types like Whit and Stage
  # cause no resource to be managed.
  unless resource_status
    result[:_error] = { msg: "Invalid resource type #{type}",
                        kind: 'apply/type-not-found',
                        details: {} }
    return result
  end

  # XXX currently ignoring noop and audit events
  failures = resource_status.events.select { |event| event.status == 'failure' }
  changes = resource_status.events.select { |event| event.status == 'success' }

  if failures.any?
    result[:failures] = failures.map do |event|
      {
        property: event.property,
        previous_value: event.previous_value,
        desired_value: event.desired_value,
        message: event.message
      }
    end
  end

  if changes.any?
    result[:changes] = changes.map do |event|
      {
        property: event.property,
        previous_value: event.previous_value,
        desired_value: event.desired_value,
        message: event.message
      }
    end
  end

  result[:changed] = true if resource_status.changed?

  if report.status == 'failed'
    error_message = failures.map(&:message).join("\n").strip

    result[:_error] = { msg: error_message,
                        kind: 'apply/resource-failure',
                        details: {} }
  end

  result
rescue StandardError => e
  result[:_error] = {
    msg: "Could not manage resource: #{e}",
    kind: 'apply/unknown-error',
    details: {}
  }
  result
end

args = JSON.parse(STDIN.read)

type = args['type']
title = args['title']
params = args['parameters']

# Required to find pluginsync'd plugins
Puppet.initialize_settings

result = apply_resource(type, title, params)
exitcode = result.key?(:_error) ? 1 : 0

puts result.to_json

exit exitcode
