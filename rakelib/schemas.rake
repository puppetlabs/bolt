# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'erb'

namespace :schemas do
  desc 'Generate all JSON schemas'
  task all: %i[
    project
    defaults
    inventory
  ]

  desc 'Generate bolt-defaults.yaml JSON schema'
  task :defaults do
    require 'bolt/config'

    filepath          = File.expand_path('../schemas/bolt-defaults.schema.json', __dir__)
    options           = Bolt::Config::DEFAULTS_OPTIONS
    inventory_options = Bolt::Config::INVENTORY_OPTIONS
    transport_options = Bolt::Config::Transport::Options::TRANSPORT_OPTIONS
    transports        = Bolt::Config::TRANSPORT_CONFIG
    definitions       = Bolt::Config::OPTIONS.slice(*options)

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
    require 'bolt/inventory'

    filepath = File.expand_path('../schemas/bolt-inventory.schema.json', __dir__)

    schema = {
      "$schema"              => "http://json-schema.org/draft-07/schema#",
      "title"                => "Bolt Inventory",
      "description"          => "Bolt Inventory inventory.yaml Schema",
      "additionalProperties" => false,
      "definitions"          => to_schema(Bolt::Config::PLUGIN)
    }

    schema = Bolt::Util.deep_merge(schema, to_schema(Bolt::Inventory.schema))

    File.write(filepath, JSON.pretty_generate(schema))

    $stdout.puts "Generated inventory.yaml schema at:\n\t#{filepath}"
  end

  desc 'Generate bolt-project.yaml JSON schema'
  task :project do
    require 'bolt/config'

    filepath    = File.expand_path('../schemas/bolt-project.schema.json', __dir__)
    options     = Bolt::Config::PROJECT_OPTIONS
    definitions = Bolt::Config::OPTIONS.slice(*options)

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
    %i[definitions description].include?(k)
  end.map(&:to_h)

  definition[:oneOf] = [
    data,
    { "$ref" => "#/definitions/_plugin" }
  ]

  definition
end

# Recurses through a definition and JSON-ifies the data types.
def to_schema(data, plugin = false)
  return data unless data.is_a?(Hash)

  # Creates JSON references
  if data.key?(:_ref)
    data["$ref"] = "#/definitions/#{data.delete(:_ref)}"
  end

  # Pull out all metadata since we don't want this in the schema.
  metadata, data = data.partition do |key, _|
    key.to_s.start_with?('_')
  end.map(&:to_h)

  # Flip plugin to true if the definition allows a plugin reference.
  # This will allow plugin references for all sub-options and items.
  plugin = metadata[:_plugin] if metadata.key?(:_plugin)

  # Recurse through some properties, as each can have their own defintions.
  %i[items additionalProperties].each do |key|
    next unless data.key?(key)
    data[key] = to_schema(data[key], plugin)
  end

  %i[properties definitions].each do |key|
    next unless data.key?(key)
    data[key] = data[key].transform_values { |opt| to_schema(opt, plugin) }
  end

  # Turn Ruby types into JSON types.
  data[:type] = to_json_types(data[:type]) if data.key?(:type)

  # Add a plugin definition if supported by the option.
  data = plugin ? add_plugin_reference(data) : data

  # Stringify keys
  data.transform_keys(&:to_s)
end
