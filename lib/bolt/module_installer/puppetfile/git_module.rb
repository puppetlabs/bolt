# frozen_string_literal: true

require 'bolt/module_installer/puppetfile/module'

# This class represents a resolved Git module.
#
module Bolt
  class ModuleInstaller
    class Puppetfile
      class GitModule < Module
        attr_reader :git, :ref

        def initialize(name, git, ref)
          super(name)
          @git  = git
          @ref  = ref
          @type = :git
        end

        # Returns a Puppetfile module specification.
        #
        def to_spec
          "mod '#{@name}',\n  git: '#{@git}',\n  ref: '#{@ref}'"
        end

        # Returns a hash that can be used to create a module specification.
        #
        def to_hash
          {
            'git' => @git,
            'ref' => @ref
          }
        end
      end
    end
  end
end
