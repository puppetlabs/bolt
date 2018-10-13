# frozen_string_literal: true

module PuppetX
  module Util
    def self.warn(msg)
      Puppet.warning(msg)
    end
  end
end
