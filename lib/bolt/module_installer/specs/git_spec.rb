# frozen_string_literal: true

require 'json'
require 'set'

require_relative '../../../bolt/error'

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
          @resolve    = init_hash.key?('resolve') ? init_hash['resolve'] : true
          @name       = parse_name(init_hash['name'])
          @git, @repo = parse_git(init_hash['git'])
          @ref        = init_hash['ref']
          @type       = :git

          if @name.nil? && @resolve == false
            raise Bolt::ValidationError,
                  "Missing name for Git module specification: #{@git}. Git module specifications "\
                  "must include a 'name' key when 'resolve' is false."
          end

          unless @resolve == true || @resolve == false
            raise Bolt::ValidationError,
                  "Option 'resolve' for module spec #{@git} must be a Boolean"
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

        # Gets the repo from the git URL.
        #
        private def parse_git(git)
          return [git, nil] unless @resolve

          repo = if git.start_with?('git@github.com:')
                   git.split('git@github.com:').last.split('.git').first
                 elsif git.start_with?('https://github.com')
                   git.split('https://github.com/').last.split('.git').first
                 else
                   raise Bolt::ValidationError, invalid_git_msg(git)
                 end

          [git, repo]
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

        # Returns an error message that the provided repo is not a git repo or
        # is private.
        #
        private def invalid_git_msg(repo_name)
          "#{repo_name} is not a public GitHub repository. See https://pup.pt/no-resolve "\
            "for information on how to install this module."
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

        # Resolves the module's title from the module metadata. This is lazily
        # resolved since Bolt does not always need to know a Git module's name.
        #
        def name
          @name ||= begin
            url      = "https://raw.githubusercontent.com/#{@repo}/#{sha}/metadata.json"
            response = make_request(:Get, url)

            case response
            when Net::HTTPOK
              body = JSON.parse(response.body)

              unless body.key?('name')
                raise Bolt::Error.new(
                  "Missing name in metadata.json at #{git}. This is not a valid module.",
                  "bolt/missing-module-name-error"
                )
              end

              parse_name(body['name'])
            else
              raise Bolt::Error.new(
                "Missing metadata.json at #{git}. This is not a valid module.",
                "bolt/missing-module-metadata-error"
              )
            end
          end
        end

        # Resolves the SHA for the specified ref. This is lazily resolved since
        # Bolt does not always need to know a Git module's SHA.
        #
        def sha
          @sha ||= begin
            url      = "https://api.github.com/repos/#{@repo}/commits/#{ref}"
            headers  = ENV['GITHUB_TOKEN'] ? { "Authorization" => "token #{ENV['GITHUB_TOKEN']}" } : {}
            response = make_request(:Get, url, headers)

            case response
            when Net::HTTPOK
              body = JSON.parse(response.body)
              body['sha']
            when Net::HTTPUnauthorized
              raise Bolt::Error.new(
                "Invalid token at GITHUB_TOKEN, unable to resolve git modules.",
                "bolt/invalid-git-token-error"
              )
            when Net::HTTPForbidden
              message = "GitHub API rate limit exceeded, unable to resolve git modules. "

              unless ENV['GITHUB_TOKEN']
                message += "To increase your rate limit, set the GITHUB_TOKEN environment "\
                          "variable with a GitHub personal access token."
              end

              raise Bolt::Error.new(message, 'bolt/github-api-rate-limit-error')
            when Net::HTTPNotFound
              raise Bolt::Error.new(invalid_git_msg(git), "bolt/missing-git-repository-error")
            else
              raise Bolt::Error.new(
                "Ref #{ref} at #{git} is not a commit, tag, or branch.",
                "bolt/invalid-git-ref-error"
              )
            end
          end
        end

        # Makes a generic HTTP request.
        #
        private def make_request(verb, url, headers = {})
          require 'net/http'

          uri      = URI.parse(url)
          opts     = { use_ssl: uri.scheme == 'https' }

          Net::HTTP.start(uri.host, uri.port, opts) do |client|
            request = Net::HTTP.const_get(verb).new(uri, headers)
            client.request(request)
          end
        rescue StandardError => e
          raise Bolt::Error.new(
            "Failed to connect to #{uri}: #{e.message}",
            "bolt/http-connect-error"
          )
        end
      end
    end
  end
end
