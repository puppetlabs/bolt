# frozen_string_literal: true

require 'json'

module Bolt
  class ResourceInstance
    attr_reader :target, :type, :title, :state, :desired_state
    attr_accessor :events

    # Needed by Puppet to recognize Bolt::ResourceInstance as a Puppet object when deserializing
    def self._pcore_type
      ResourceInstance
    end

    # Needed by Puppet to serialize with _pcore_init_hash instead of the object's attributes
    def self._pcore_init_from_hash(_init_hash)
      raise "ResourceInstance shouldn't be instantiated from a pcore_init class method. "\
            "How did this get called?"
    end

    def _pcore_init_from_hash(init_hash)
      initialize(init_hash)
    end

    # Parameters will already be validated when calling ResourceInstance.new or
    # set_resources() from a plan. We don't perform any validation in the class
    # itself since Puppet will pass an empty hash to the initializer as part of
    # the deserialization process before passing the _pcore_init_hash.
    def initialize(resource_hash)
      @target        = resource_hash['target']
      @type          = resource_hash['type'].to_s.capitalize
      @title         = resource_hash['title']
      @state         = resource_hash['state'] || {}
      @desired_state = resource_hash['desired_state'] || {}
      @events        = resource_hash['events'] || []
    end

    # Creates a ResourceInstance from a data hash in a plan when calling
    # ResourceInstance.new($resource_hash) or $target.set_resources($resource_hash)
    def self.from_asserted_hash(resource_hash)
      new(resource_hash)
    end

    # Creates a ResourceInstance from positional arguments in a plan when
    # calling ResourceInstance.new(target, type, title, ...)
    def self.from_asserted_args(target,
                                type,
                                title,
                                state         = nil,
                                desired_state = nil,
                                events        = nil)
      new(
        'target'        => target,
        'type'          => type,
        'title'         => title,
        'state'         => state,
        'desired_state' => desired_state,
        'events'        => events
      )
    end

    def eql?(other)
      self.class.equal?(other.class) &&
        target == other.target &&
        type   == other.type &&
        title  == other.title
    end
    alias == eql?

    def to_hash
      {
        'target'        => target,
        'type'          => type,
        'title'         => title,
        'state'         => state,
        'desired_state' => desired_state,
        'events'        => events
      }
    end
    alias _pcore_init_hash to_hash

    def to_json(opts = nil)
      to_hash.to_json(opts)
    end

    def reference
      "#{type}[#{title}]"
    end
    alias to_s reference

    def add_event(event)
      @events << event
    end

    # rubocop:disable Naming/AccessorMethodName
    def set_state(state)
      assert_hash('state', state)
      @state.merge!(state)
    end
    # rubocop:enable Naming/AccessorMethodName

    def overwrite_state(state)
      assert_hash('state', state)
      @state = state
    end

    # rubocop:disable Naming/AccessorMethodName
    def set_desired_state(desired_state)
      assert_hash('desired_state', desired_state)
      @desired_state.merge!(desired_state)
    end
    # rubocop:enable Naming/AccessorMethodName

    def overwrite_desired_state(desired_state)
      assert_hash('desired_state', desired_state)
      @desired_state = desired_state
    end

    def assert_hash(loc, value)
      unless value.is_a?(Hash)
        raise Bolt::ValidationError, "#{loc} must be of type Hash; got #{value.class}"
      end
    end
  end
end
