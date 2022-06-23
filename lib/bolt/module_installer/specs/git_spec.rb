# frozen_string_literal: true

require 'json'
require 'net/http'
require 'open3'
require 'set'

require_relative '../../../bolt/error'
require_relative '../../../bolt/logger'

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

        def initialize(init_hash)
          @logger  = Bolt::Logger.logger(self)
          @resolve = init_hash.key?('resolve') ? init_hash['resolve'] : true
          @git     = init_hash['git']
          @ref     = init_hash['ref']
          @name    = parse_name(init_hash['name'])
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
                  "Invalid URI #{@git}. Valid URIs must begin with 'git@', 'http://', or 'https://'."
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
            mod.ref    = @ref
          end
        end

        # Resolves the module's title from the module metadata. This is lazily
        # resolved since Bolt does not always need to know a Git module's name,
        # and fetching the metadata to figure it out is expensive.
        #
        def name
          @name ||= parse_name(metadata['name'])
        end

        # Fetches the module's metadata. Attempts to fetch metadata from either
        # GitHub or GitLab and falls back to cloning the repo if that fails.
        #
        private def metadata
          data = github_metadata || gitlab_metadata || clone_metadata

          unless data
            raise Bolt::Error.new(
              "Unable to locate metadata.json for module at #{@git}. This may not be a valid module. "\
              "For more information about how Bolt attempted to locate the metadata file, check the "\
              "debugging logs.",
              'bolt/missing-module-metadata-error'
            )
          end

          data = JSON.parse(data)

          unless data.is_a?(Hash)
            raise Bolt::Error.new(
              "Invalid metadata.json at #{@git}. Expected a Hash, got a #{data.class}.",
              'bolt/invalid-module-metadata-error'
            )
          end

          unless data.key?('name')
            raise Bolt::Error.new(
              "Invalid metadata.json at #{@git}. Metadata must include a 'name' key.",
              'bolt/missing-module-name-error'
            )
          end

          data
        rescue JSON::ParserError => e
          raise Bolt::Error.new(
            "Unable to parse metadata.json for module at #{@git}: #{e.message}",
            'bolt/metadata-parse-error'
          )
        end

        # Returns the metadata for a GitHub-hosted module.
        #
        private def github_metadata
          repo = if @git.start_with?('git@github.com:')
                   @git.split('git@github.com:').last.split('.git').first
                 elsif @git.start_with?('https://github.com')
                   @git.split('https://github.com/').last.split('.git').first
                 end

          return nil if repo.nil?

          request_metadata("https://raw.githubusercontent.com/#{repo}/#{@ref}/metadata.json")
        end

        # Returns the metadata for a GitLab-hosted module.
        #
        private def gitlab_metadata
          repo = if @git.start_with?('git@gitlab.com:')
                   @git.split('git@gitlab.com:').last.split('.git').first
                 elsif @git.start_with?('https://gitlab.com')
                   @git.split('https://gitlab.com/').last.split('.git').first
                 end

          return nil if repo.nil?

          request_metadata("https://gitlab.com/#{repo}/-/raw/#{@ref}/metadata.json")
        end

        # Returns the metadata by cloning a git-based module.
        # Because cloning is the last attempt to locate module metadata
        #
        private def clone_metadata
          unless git?
            @logger.debug("'git' executable not found, unable to use git clone resolution.")
            return nil
          end

          # Clone the repo into a temp directory that will be automatically cleaned up.
          Dir.mktmpdir do |dir|
            command = %W[git clone --bare --depth=1 --single-branch --branch=#{@ref} #{@git} #{dir}]
            @logger.debug("Executing command '#{command.join(' ')}'")

            out, err, status = Open3.capture3(*command)

            unless status.success?
              @logger.debug("Unable to clone #{@git}: #{err}")
              return nil
            end

            # Read the metadata.json file from the cloned repo.
            Dir.chdir(dir) do
              command = %W[git show #{@ref}:metadata.json]
              @logger.debug("Executing command '#{command.join(' ')}'")

              out, err, status = Open3.capture3(*command)

              unless status.success?
                @logger.debug("Unable to read metadata.json file for #{@git}: #{err}")
                return nil
              end

              out
            end
          end
        end

        # Requests module metadata from the specified url.
        #
        private def request_metadata(url)
          uri  = URI.parse(url)
          opts = { use_ssl: uri.scheme == 'https' }

          @logger.debug("Requesting metadata file from #{url}")

          Net::HTTP.start(uri.host, uri.port, opts) do |client|
            response = client.request(Net::HTTP::Get.new(uri))

            case response
            when Net::HTTPOK
              response.body
            else
              @logger.debug("Unable to locate metadata file at #{url}")
              nil
            end
          end
        rescue StandardError => e
          raise Bolt::Error.new(
            "Failed to connect to #{uri}: #{e.message}",
            "bolt/http-connect-error"
          )
        end

        # Returns true if the 'git' executable is available.
        #
        private def git?
          Open3.capture3('git', '--version')
          true
        rescue Errno::ENOENT
          false
        end

        # Returns true if the URL is valid.
        #
        private def valid_url?(url)
          return true if url.start_with?('git@')

          uri = URI.parse(url)
          uri.is_a?(URI::HTTP) && uri.host
        rescue URI::InvalidURIError
          false
        end
      end
    end
  end
end
