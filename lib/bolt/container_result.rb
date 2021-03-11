# frozen_string_literal: true

require 'json'
require 'bolt/error'
require 'bolt/result'

module Bolt
  class ContainerResult
    attr_reader :value, :object

    def self.from_exception(exception, exit_code, image, position: [])
      details = Bolt::Result.create_details(position)
      error = {
        'kind' => 'puppetlabs.tasks/container-error',
        'issue_code' => 'CONTAINER_ERROR',
        'msg' => "Error running container '#{image}': #{exception}",
        'details' => details
      }
      error['details']['exit_code'] = exit_code
      ContainerResult.new({ '_error' => error }, object: image)
    end

    def _pcore_init_hash
      { 'value' => @value,
        'object' => @image }
    end

    # First argument can't be named given the way that Puppet deserializes variables
    def initialize(value = nil, object: nil)
      @value = value || {}
      @object = object
    end

    def eql?(other)
      self.class == other.class &&
        value == other.value
    end
    alias == eql?

    def [](key)
      value[key]
    end

    def to_json(opts = nil)
      to_data.to_json(opts)
    end
    alias to_s to_json

    # This is the value with all non-UTF-8 characters removed, suitable for
    # printing or converting to JSON. It *should* only be possible to have
    # non-UTF-8 characters in stdout/stderr keys as they are not allowed from
    # tasks but we scrub the whole thing just in case.
    def safe_value
      Bolt::Util.walk_vals(value) do |val|
        if val.is_a?(String)
          # Replace invalid bytes with hex codes, ie. \xDE\xAD\xBE\xEF
          val.scrub { |c| c.bytes.map { |b| "\\x" + b.to_s(16).upcase }.join }
        else
          val
        end
      end
    end

    def stdout
      value['stdout']
    end

    def stderr
      value['stderr']
    end

    def to_data
      {
        "object" => object,
        "status" => status,
        "value" => safe_value
      }
    end

    def status
      ok? ? 'success' : 'failure'
    end

    def ok?
      error_hash.nil?
    end
    alias ok ok?
    alias success? ok?

    # This allows access to errors outside puppet compilation
    # it should be prefered over error in bolt code
    def error_hash
      value['_error']
    end

    # Warning: This will fail outside of a compilation.
    # Use error_hash inside bolt.
    # Is it crazy for this to behave differently outside a compiler?
    def error
      if error_hash
        Puppet::DataTypes::Error.from_asserted_hash(error_hash)
      end
    end
  end
end
