require 'logger'

module Bolt
  class << self
    attr_accessor :log_level
    attr_accessor :config
  end

  @config = {}

  require 'bolt/executor'
  require 'bolt/node'
end
