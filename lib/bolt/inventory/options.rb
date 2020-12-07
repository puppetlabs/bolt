# frozen_string_literal: true

require 'bolt/config/options'

module Bolt
  class Inventory
    module Options
      # Top-level options available in the inventory.
      OPTIONS = %w[
        config
        facts
        features
        groups
        targets
        vars
      ].freeze

      # Definitions used to validate the data.
      # https://github.com/puppetlabs/bolt/blob/main/schemas/README.md
      DEFINITIONS = {
        "alias" => {
          description: "A unique alias to refer to the target. Aliases cannot conflict "\
                       "with the name of a group, the name of a target, or another alias.",
          type: [String, Array],
          uniqueItems: true,
          items: {
            type: String,
            _plugin: true
          },
          _plugin: true
        },
        "config" => {
          description: "A map of configuration options.",
          type: Hash,
          # These properties are populated as part of Bolt::Inventory.schema
          properties: {},
          _plugin: true
        },
        "facts" => {
          description: "A map of system information, also known as facts, for the target.",
          type: Hash,
          _plugin: true
        },
        "features" => {
          description: "A list of available features for the target.",
          type: Array,
          uniqueItems: true,
          items: {
            type: String,
            _plugin: true
          },
          _plugin: true
        },
        "groups" => {
          description: "A list of groups and their associated configuration.",
          type: Array,
          items: {
            type: Hash,
            required: ["name"],
            properties: {
              "config"       => { _ref: "config" },
              "facts"        => { _ref: "facts" },
              "features"     => { _ref: "features" },
              "groups"       => { _ref: "groups" },
              "name"         => { _ref: "name" },
              "plugin_hooks" => { _ref: "plugin_hooks" },
              "targets"      => { _ref: "targets" },
              "vars"         => { _ref: "vars" }
            },
            _plugin: true
          },
          _plugin: true
        },
        "name" => {
          description: "A human-readable name to refer to the group or target. Names "\
                       "cannot conflict with the name of a group, the name of a target, "\
                       "or the alias of a target. A name is required for a group and is "\
                       "required for a target unless the uri option is set.",
          type: String,
          _plugin: true
        },
        "plugin_hooks" => {
          description: "Configuration for the Puppet library plugin used to install the "\
                       "Puppet agent on the target. For more information, see "\
                       "https://pup.pt/bolt-plugin-hooks",
          type: Hash,
          properties: {
            "puppet_library" => {
              description: "Configuration for the Puppet library plugin.",
              type: Hash,
              _plugin: true
            }
          },
          _plugin: true
        },
        "targets" => {
          description: "A list of targets and their associated configuration.",
          type: Array,
          items: {
            type: [String, Hash],
            properties: {
              "alias"        => { _ref: "alias" },
              "config"       => { _ref: "config" },
              "facts"        => { _ref: "facts" },
              "features"     => { _ref: "features" },
              "name"         => { _ref: "name" },
              "plugin_hooks" => { _ref: "plugin_hooks" },
              "uri"          => { _ref: "uri" },
              "vars"         => { _ref: "vars" }
            },
            _plugin: true
          },
          _plugin: true
        },
        "uri" => {
          description: "The URI of the target. This option is required unless the name "\
                       "option is set.",
          type: String,
          format: "uri",
          _plugin: true
        },
        "vars" => {
          description: "A map of variables for the group or target.",
          type: Hash,
          _plugin: true
        }
      }.freeze
    end
  end
end
