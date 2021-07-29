# frozen_string_literal: true

require_relative '../../../bolt/error'

module Bolt
  class ModuleInstaller
    class Puppetfile
      class Module
        attr_reader :full_name, :name, :type

        def initialize(name)
          @full_name, @name = parse_name(name)
        end

        # Formats the full name and extracts the module name.
        #
        protected def parse_name(name)
          full_name     = name.tr('-', '/')
          first, second = full_name.split('/', 2)

          [full_name, second || first]
        end
      end
    end
  end
end
