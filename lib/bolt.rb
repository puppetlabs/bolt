require 'logger'

module Bolt
  class << self
    attr_accessor :log_level
  end

  require 'bolt/executor'
  require 'bolt/node'
end
