# frozen_string_literal: true

require 'json'
require 'net/http'
require 'open3'
require 'set'

require_relative '../../../bolt/error'
require_relative '../../../bolt/logger'
require_relative '../../../bolt/module_installer/specs/id/gitclone'
require_relative '../../../bolt/module_installer/specs/id/github'
require_relative '../../../bolt/module_installer/specs/id/gitlab'

# This class represents a Git module specification.
#
module Bolt
  class ModuleInstaller
    class Specs
      class GitSpec
        NAME_REGEX    = %r{\A(?:[a-zA-Z0-9]+[-/])?(?<name>[a-z][a-z0-9_]*)\z}.freeze
        REQUIRED_KEYS = Set.new(%w[git ref]).freeze
        KNOWN_KEYS    = Set.new(%w[git name ref resolve]).freeze

        attr_reader :git, :ref, :resolve, :type

        def initialize(init_hash, config = {})
          @logger  = Bolt::Logger.logger(self)
          @resolve = init_hash.key?('resolve') ? init_hash['resolve'] : true
          @git     = init_hash['git']
          @ref     = init_hash['ref']
          @name    = parse_name(init_hash['name'])
          @proxy   = config.dig('proxy')
          @type    = :git

          unless @resolve == true || @resolve == false
            raise Bolt::ValidationError,
                  "Option 'resolve' for module spec #{@git} must be a Boolean"
          end

          if @name.nil? && @resolve == false
            raise Bolt::ValidationError,
                  "Missing name for Git module specification: #{@git}. Git module specifications "\
                  "must include a 'name' key when 'resolve' is false."
          end

          unless valid_url?(@git)
            raise Bolt::ValidationError,
                  "Invalid URI #{@git}. Valid URIs must begin with 'git@', 'http://', 'https://' or 'ssh://'."
          end
        end

        def self.implements?(hash)
          KNOWN_KEYS.superset?(hash.keys.to_set) && REQUIRED_KEYS.subset?(hash.keys.to_set)
        end

        # Parses the name into owner and name segments, and formats the full
        # name.
        #
        private def parse_name(name)
          return unless name

          unless (match = name.match(NAME_REGEX))
            raise Bolt::ValidationError,
                  "Invalid name for Git module specification: #{name}. Name must match "\
                  "'name' or 'owner/name'. Owner segment can only include letters or digits. "\
                  "Name segment must start with a lowercase letter and can only include "\
                  "lowercase letters, digits, and underscores."
          end

          match[:name]
        end

        # Returns true if the specification is satisfied by the module.
        #
        def satisfied_by?(mod)
          @type == mod.type && @git == mod.git
        end

        # Returns a hash matching the module spec in bolt-project.yaml
        #
        def to_hash
          {
            'git' => @git,
            'ref' => @ref
          }
        end

        # Returns a PuppetfileResolver::Model::GitModule object for resolving.
        #
        def to_resolver_module
          require 'puppetfile-resolver'

          PuppetfileResolver::Puppetfile::GitModule.new(name).tap do |mod|
            mod.remote = @git
            mod.ref    = sha
          end
        end

        # Returns the module's name.
        #
        def name
          @name ||= parse_name(id.name)
        end

        # Returns the SHA for the module's ref.
        #
        def sha
          id.sha
        end

        # Gets the ID for the module based on the specified ref and git URL.
        # This is lazily resolved since Bolt does not always need this information,
        # and requesting it is expensive.
        #
        private def id
          @id ||= begin
            # The request methods here return an ID object if the module name and SHA
            # were found and nil otherwise. This lets Bolt try multiple methods for
            # finding the module name and SHA, and short circuiting as soon as it does.
            module_id = Bolt::ModuleInstaller::Specs::ID::GitHub.request(@git, @ref, @proxy) ||
                        Bolt::ModuleInstaller::Specs::ID::GitLab.request(@git, @ref, @proxy) ||
                        Bolt::ModuleInstaller::Specs::ID::GitClone.request(@git, @ref, @proxy)

            unless module_id
              raise Bolt::Error.new(
                "Unable to locate metadata and calculate SHA for ref #{@ref} at #{@git}. This may "\
                "not be a valid module. For more information about how Bolt attempted to locate "\
                "this information, check the debugging logs.",
                'bolt/missing-module-metadata-error'
              )
            end

            module_id
          end
        end

        # Returns true if the URL is valid.
        #
        private def valid_url?(url)
          return true if url.start_with?('git@')

          uri = URI.parse(url)
          (uri.is_a?(URI::HTTP) || uri.scheme == "ssh") && uri.host
        rescue URI::InvalidURIError
          false
        end
      end
    end
  end
end
