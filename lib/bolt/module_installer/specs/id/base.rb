# frozen_string_literal: true

require 'json'
require 'net/http'

require_relative '../../../../bolt/error'
require_relative '../../../../bolt/logger'

module Bolt
  class ModuleInstaller
    class Specs
      class ID
        class Base
          attr_reader :name, :sha

          # @param name [String] The module's name.
          # @param sha [String] The ref's SHA1.
          #
          def initialize(name, sha)
            @name = name
            @sha  = sha
          end

          # Request the name and SHA for a module and ref.
          # This method must return either an ID object or nil. The GitSpec
          # class relies on this class to return an ID object to indicate
          # the module was found, or nil to indicate that it should try to
          # find it another way (such as cloning the repo).
          #
          # @param git [String] The URL to the git repo.
          # @param ref [String] The ref to checkout.
          # @param proxy [String] A proxy to use when making requests.
          #
          def self.request(git, ref, proxy)
            name, sha = name_and_sha(git, ref, proxy)
            name && sha ? new(name, sha) : nil
          end

          # Stub method for retrieving the module's name and SHA. Must
          # be implemented by all sub classes.
          #
          private_class_method def self.name_and_sha(_git, _ref, _proxy)
            raise NotImplementedError, 'Class does not implemented #name_and_sha'
          end

          # Makes a HTTP request.
          #
          # @param url [String] The URL to make the request to.
          # @param proxy [String] A proxy to use when making the request.
          # @param headers [Hash] Headers to send with the request.
          #
          private_class_method def self.make_request(url, proxy, headers = {})
            uri  = URI.parse(url)
            opts = { use_ssl: uri.scheme == 'https' }
            args = [uri.host, uri.port]

            if proxy
              proxy = URI.parse(proxy)
              args += [proxy.host, proxy.port, proxy.user, proxy.password]
            end

            Bolt::Logger.debug("Making request to #{loc(url, proxy)}")

            Net::HTTP.start(*args, opts) do |client|
              client.request(Net::HTTP::Get.new(uri, headers))
            end
          rescue StandardError => e
            raise Bolt::Error.new(
              "Failed to connect to #{loc(uri, proxy)}: #{e.message}",
              "bolt/http-connect-error"
            )
          end

          # Returns a formatted string describing the URL and proxy used when making
          # a request.
          #
          # @param url [String, URI::HTTP] The URL used.
          # @param proxy [String, URI::HTTP] The proxy used.
          #
          private_class_method def self.loc(url, proxy)
            proxy ? "#{url} with proxy #{proxy}" : url.to_s
          end

          # Parses the metadata and validates that it is a Hash.
          #
          # @param metadata [String] The JSON data to parse.
          #
          private_class_method def self.parse_name_from_metadata(metadata)
            metadata = JSON.parse(metadata)

            unless metadata.is_a?(Hash)
              raise Bolt::Error.new(
                "Invalid metadata. Expected a Hash, got a #{metadata.class}: #{metadata}",
                "bolt/invalid-module-metadata-error"
              )
            end

            unless metadata.key?('name')
              raise Bolt::Error.new(
                "Invalid metadata. Metadata must include a 'name' key.",
                "bolt/missing-module-name-error"
              )
            end

            metadata['name']
          rescue JSON::ParserError => e
            raise Bolt::Error.new(
              "Unable to parse metadata as JSON: #{e.message}",
              "bolt/metadata-parse-error"
            )
          end
        end
      end
    end
  end
end
