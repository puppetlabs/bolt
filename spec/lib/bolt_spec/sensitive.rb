# frozen_string_literal: true

require 'puppet/pops/types/p_sensitive_type'

module BoltSpec
  module Sensitive
    def make_sensitive(val)
      Puppet::Pops::Types::PSensitiveType::Sensitive.new(val)
    end
  end
end
