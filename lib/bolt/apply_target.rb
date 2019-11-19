# frozen_string_literal: true

module Bolt
  # Alt: ReadOnlyTarget
  class ApplyTarget
    ATTRIBUTES = %i[uri name target_alias config vars facts features
                    plugin_hooks safe_name host password port protocol user].freeze

    attr_reader *ATTRIBUTES, :target_hash

    # Puppet calls this method when it needs an instance of this type
    def self.from_asserted_hash(target_hash)
      new(target_hash)
    end

    def self.from_asserted_args(target_hash)
      new(target_hash)
    end

    def initialize(target_hash)
      # TODO: Do we actually need this?
      @target_hash = target_hash
      ATTRIBUTES.each do |attr|
        instance_variable_set("@#{attr}", target_hash[attr.to_s])
      end
    end
  end
end
