# frozen_string_literal: true

require 'json'
require 'bolt/error'
require 'bolt/util'

module Bolt
  class PlanResult
    attr_accessor :status, :value

    # This must be called from inside a compiler
    def self.from_pcore(result, status)
      result = Bolt::Util.walk_vals(result) do |v|
        if v.is_a?(Puppet::DataTypes::Error)
          Bolt::PuppetError.from_error(v)
        else
          v
        end
      end
      new(result, status)
    end

    def initialize(value, status)
      @value = value
      @status = status
    end

    def ok?
      @status == 'success'
    end

    def ==(other)
      value == other.value && status == other.status
    end

    def to_json(*args)
      @value.to_json(*args)
    end

    def to_s
      to_json
    end
  end
end
