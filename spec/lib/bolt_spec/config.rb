# frozen_string_literal: true

require 'bolt/config'

module BoltSpec
  module Config
    def make_config(overrides = {})
      overrides = Bolt::Util.walk_keys(overrides, &:to_s)
      project = Bolt::Project.new({}, '.')
      Bolt::Config.new(project, overrides)
    end
  end
end
