# frozen_string_literal: true

require_relative '../bolt/error'
require_relative 'puppetdb/client'
require_relative 'puppetdb/config'

module Bolt
  class PuppetDBError < Bolt::Error
    def initialize(msg)
      super(msg, "bolt/puppetdb-error")
    end
  end

  class PuppetDBFailoverError < PuppetDBError; end
end
