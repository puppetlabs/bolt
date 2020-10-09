# frozen_string_literal: true

require 'bolt/config'

module Bolt
  class Config
    class Modulepath
      BOLTLIB_PATH = File.expand_path('../../../bolt-modules', __dir__)
      MODULES_PATH = File.expand_path('../../../modules', __dir__)

      # The user_modulepath only includes the original modulepath and is used during pluginsync.
      # We don't want to pluginsync any of the content from BOLT_MODULES since that content
      # includes core modules that can conflict with modules installed with an agent.
      attr_reader :user_modulepath

      def initialize(user_modulepath, boltlib_path: BOLTLIB_PATH, builtin_content_path: MODULES_PATH)
        @user_modulepath = Array(user_modulepath).flatten
        @boltlib_path = Array(boltlib_path).flatten
        @builtin_content_path = Array(builtin_content_path).flatten
      end

      # The full_modulepath includes both the BOLTLIB
      # path and the MODULES_PATH to ensure bolt functions and
      # built-in content are available in the compliler
      def full_modulepath
        @boltlib_path + @user_modulepath + @builtin_content_path
      end
    end
  end
end
