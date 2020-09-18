# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'erb'

namespace :schemas do
  desc 'Generate all JSON schemas'
  task all: %i[
    project
    defaults
    config
    inventory
  ]

  desc 'Generate bolt.yaml JSON schema'
  task :config do
    require 'bolt/config'

    filepath          = File.expand_path('../schemas/bolt-config.schema.json', __dir__)
    options           = Bolt::Config::Options::BOLT_OPTIONS.dup
    inventory_options = Bolt::Config::Options::INVENTORY_OPTIONS
    transport_options = Bolt::Config::Transport::Options::TRANSPORT_OPTIONS
    transports        = Bolt::Config::TRANSPORT_CONFIG
    definitions       = Bolt::Config::Options::OPTIONS.slice(*options)

    properties = options.concat(inventory_options.keys).each_with_object({}) do |option, acc|
      acc[option] = { "$ref" => "#/definitions/#{option}" }
    end

    # Add transport definitions to the definitions hash
    definitions = definitions.merge(inventory_options)

    # Add transport option definition references to each transport definition
    transports.each do |option, transport|
      definitions[option][:properties] = transport.options.each_with_object({}) do |opt, acc|
        acc[opt] = { "$ref" => "#/transport_definitions/#{opt}" }
      end
    end

    definitions = definitions.transform_values do |data|
      to_schema(data)
    end

    transport_definitions = transport_options.transform_values do |data|
      to_schema(data)
    end

    definitions = definitions.merge(Bolt::Config::Options::PLUGIN)

    schema = {
      "$schema"               => "http://json-schema.org/draft-07/schema#",
      "title"                 => "Bolt Configuration",
      "description"           => "Bolt Configuration bolt.yaml Schema",
      "type"                  => "object",
      "properties"            => properties,
      "definitions"           => definitions,
      "transport_definitions" => transport_definitions
    }

    json = JSON.pretty_generate(schema)

    File.write(filepath, json)

    $stdout.puts "Generated bolt.yaml schema at:\n\t#{filepath}"
  end

  desc 'Generate bolt-defaults.yaml JSON schema'
  task :defaults do
    require 'bolt/config'

    filepath          = File.expand_path('../schemas/bolt-defaults.schema.json', __dir__)
    options           = Bolt::Config::Options::BOLT_DEFAULTS_OPTIONS
    inventory_options = Bolt::Config::Options::INVENTORY_OPTIONS
    transport_options = Bolt::Config::Transport::Options::TRANSPORT_OPTIONS
    transports        = Bolt::Config::TRANSPORT_CONFIG
    definitions       = Bolt::Config::Options::OPTIONS.slice(*options)

    properties = options.each_with_object({}) do |option, acc|
      acc[option] = { "$ref" => "#/definitions/#{option}" }
    end

    # Add inventory option definition references to the 'inventory-config' option
    definitions['inventory-config'][:properties] = inventory_options.each_with_object({}) do |(option, _), acc|
      acc[option] = { "$ref" => "#/definitions/#{option}" }
    end

    # Add transport definitions to the definitions hash
    definitions = definitions.merge(inventory_options)

    # Add transport option definition references to each transport definition
    transports.each do |option, transport|
      definitions[option][:properties] = transport.options.each_with_object({}) do |opt, acc|
        acc[opt] = { "$ref" => "#/transport_definitions/#{opt}" }
      end
    end

    definitions = definitions.transform_values do |data|
      to_schema(data)
    end

    transport_definitions = transport_options.transform_values do |data|
      to_schema(data)
    end

    definitions = definitions.merge(Bolt::Config::Options::PLUGIN)

    schema = {
      "$schema"               => "http://json-schema.org/draft-07/schema#",
      "title"                 => "Bolt Defaults",
      "description"           => "Bolt Defaults bolt-defaults.yaml Schema",
      "type"                  => "object",
      "properties"            => properties,
      "definitions"           => definitions,
      "transport_definitions" => transport_definitions
    }

    json = JSON.pretty_generate(schema)

    File.write(filepath, json)

    $stdout.puts "Generated bolt-defaults.yaml schema at:\n\t#{filepath}"
  end

  # The inventory schema is generated from a template as opposed to an OPTIONS hash
  # as it has a more complicated structure than the other schemas. However, the
  # transport configuration options are generated from OPTIONS hashes and are added
  # to the base schema.
  desc 'Generate inventory.yaml JSON schema'
  task :inventory do
    require 'bolt/config'

    filepath          = File.expand_path('../schemas/bolt-inventory.schema.json', __dir__)
    base              = JSON.parse(File.read(File.expand_path('../schemas/bolt-inventory-base.json', __dir__)))
    inventory_options = Bolt::Config::INVENTORY_OPTIONS
    transport_options = Bolt::Config::Transport::Options::TRANSPORT_OPTIONS
    transports        = Bolt::Config::TRANSPORT_CONFIG

    # Add transport definition references to the 'config' option.
    config_properties = inventory_options.keys.each_with_object({}) do |option, acc|
      acc[option] = { "$ref" => "#/definitions/#{option}" }
    end

    # The base schema already includes the 'oneOf' key. These properties should
    # be added to the first element of that array.
    base['definitions']['config']['oneOf'][0]['properties'] = config_properties

    # Add transport option definitions references to the transport definitions
    transports.each do |option, transport|
      inventory_options[option][:properties] = transport.options.each_with_object({}) do |opt, acc|
        acc[opt] = { "$ref" => "#/transport_definitions/#{opt}" }
      end
    end

    # Add transport definitions
    inventory_options.each do |option, definition|
      base['definitions'][option] = to_schema(definition)
    end

    # Add transport option definitions
    base['transport_definitions'] = transport_options.transform_values do |data|
      to_schema(data)
    end

    # Add _plugin definition
    base['definitions'] = base['definitions'].merge(Bolt::Config::PLUGIN)

    json = JSON.pretty_generate(base)

    File.write(filepath, json)

    $stdout.puts "Generated inventory.yaml schema at:\n\t#{filepath}"
  end

  desc 'Generate bolt-project.yaml JSON schema'
  task :project do
    require 'bolt/config'

    filepath    = File.expand_path('../schemas/bolt-project.schema.json', __dir__)
    options     = Bolt::Config::BOLT_PROJECT_OPTIONS - ['modules']
    definitions = Bolt::Config::Options::OPTIONS.slice(*options)

    properties = options.each_with_object({}) do |option, acc|
      acc[option] = { "$ref" => "#/definitions/#{option}" }
    end

    definitions = definitions.transform_values do |data|
      to_schema(data)
    end

    definitions = definitions.merge(Bolt::Config::Options::PLUGIN)

    schema = {
      "$schema"     => "http://json-schema.org/draft-07/schema#",
      "title"       => "Bolt Project",
      "description" => "Bolt Project bolt-project.yaml Schema",
      "type"        => "object",
      "properties"  => properties,
      "definitions" => definitions
    }

    json = JSON.pretty_generate(schema)

    File.write(filepath, json)

    $stdout.puts "Generated bolt-defaults.yaml schema at:\n\t#{filepath}"
  end
end

def to_json_types(ruby_types)
  # Pull out the type and turn it into an array. This allows us to
  # handle single types and multi-types the same way.
  types = Array(ruby_types)

  # Now we can replace the Ruby classes with stringified JSON types.
  # Since Ruby does not have a Boolean class, we replace both TrueClass
  # and FalseClass with 'boolean' then make sure the types array has
  # unique values.
  types = types.map do |type|
    case type.to_s
    when 'Hash'
      'object'
    when 'TrueClass', 'FalseClass'
      'boolean'
    when 'String', 'Integer', 'Array'
      type.to_s.downcase
    else
      raise "Cannot convert Ruby type to JSON type: #{type}"
    end
  end.uniq

  # If there is only a single valid type, un-Array-ify it.
  types.length > 1 ? types : types.first
end

def add_plugin_reference(definition)
  definition, data = definition.partition do |k, _|
    k == :description
  end.map(&:to_h)

  definition[:oneOf] = [
    data,
    { "$ref" => "#/definitions/_plugin" }
  ]

  definition
end

# Recurses through a definition and JSON-ifies the data types.
def to_schema(data)
  return data unless data.is_a?(Hash)

  # Pull out all metadata since we don't want this in the schema.
  metadata, data = data.partition do |key, _|
    key.to_s.start_with?('_')
  end.map(&:to_h)

  # Recurse through :items, :additionalProperties, and :properties,
  # since each of these can have their own definitions.
  %i[items additionalProperties].each do |key|
    next unless data.key?(key)
    data[key] = to_schema(data[key])
  end

  if data.key?(:properties)
    data[:properties] = data[:properties].transform_values do |definition|
      to_schema(definition)
    end
  end

  # Turn Ruby types into JSON types.
  data[:type] = to_json_types(data[:type]) if data.key?(:type)

  # Add a plugin definition if supported by the option.
  metadata[:_plugin] ? add_plugin_reference(data) : data
end
