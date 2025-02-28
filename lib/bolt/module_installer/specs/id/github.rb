# frozen_string_literal: true

require_relative '../../../../bolt/module_installer/specs/id/base'

module Bolt
  class ModuleInstaller
    class Specs
      class ID
        class GitHub < Base
          # Returns the name and SHA for the module at the given ref.
          #
          # @param git [String] The URL to the git repo.
          # @param ref [String] The ref to use.
          # @param proxy [String] The proxy to use when making requests.
          #
          private_class_method def self.name_and_sha(git, ref, proxy)
            repo = parse_repo(git)
            return nil unless repo
            [request_name(repo, ref, proxy), request_sha(repo, ref, proxy)]
          end

          # Parses the repo path out of the URL.
          #
          # @param git [String] The URL to the git repo.
          #
          private_class_method def self.parse_repo(git)
            if git.start_with?('git@github.com:')
              git.split('git@github.com:').last.split('.git').first
            elsif git.start_with?('https://github.com')
              git.split('https://github.com/').last.split('.git').first
            end
          end

          # Requests a module's metadata and returns the name from it.
          #
          # @param repo [String] The repo ID, i.e. 'owner/repo'
          # @param ref [String] The ref to use.
          # @param proxy [String] The proxy to use when making requests.
          #
          private_class_method def self.request_name(repo, ref, proxy)
            metadata_url = "https://raw.githubusercontent.com/#{repo}/#{ref}/metadata.json"
            response     = make_request(metadata_url, proxy)

            case response
            when Net::HTTPOK
              Bolt::Logger.debug("Found metadata file at #{loc(metadata_url, proxy)}")
              parse_name_from_metadata(response.body)
            else
              Bolt::Logger.debug("Unable to find metadata file at #{loc(metadata_url, proxy)}")
              nil
            end
          end

          # Requests the SHA for the specified ref.
          #
          # @param repo [String] The repo ID, i.e. 'owner/repo'
          # @param ref [String] The ref to resolve.
          # @param proxy [String] The proxy to use when making requests.
          #
          private_class_method def self.request_sha(repo, ref, proxy)
            url      = "https://api.github.com/repos/#{repo}/commits/#{ref}"
            headers  = ENV['GITHUB_TOKEN'] ? { "Authorization" => "token #{ENV['GITHUB_TOKEN']}" } : {}
            response = make_request(url, proxy, headers)

            case response
            when Net::HTTPOK
              JSON.parse(response.body).fetch('sha', nil)
            when Net::HTTPUnauthorized
              Bolt::Logger.debug("Invalid token at GITHUB_TOKEN, unable to calculate SHA.")
              nil
            when Net::HTTPForbidden
              message = "GitHub API rate limit exceeded, unable to calculate SHA."

              unless ENV['GITHUB_TOKEN']
                message += " To increase your rate limit, set the GITHUB_TOKEN environment " \
                          "variable with a GitHub personal access token."
              end

              Bolt::Logger.debug(message)
              nil
            else
              Bolt::Logger.debug("Unable to calculate SHA for ref #{ref}")
              nil
            end
          end
        end
      end
    end
  end
end
