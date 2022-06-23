# frozen_string_literal: true

require_relative '../../../../bolt/module_installer/specs/id/base'

module Bolt
  class ModuleInstaller
    class Specs
      class ID
        class GitClone < Base
          # Returns the name and SHA for the module at the given ref.
          #
          # @param git [String] The URL to the git repo.
          # @param ref [String] The ref to checkout.
          # @param proxy [String] The proxy to use when cloning.
          #
          private_class_method def self.name_and_sha(git, ref, proxy)
            require 'open3'

            unless git?
              Bolt::Logger.debug("'git' executable not found, unable to use git clone resolution.")
              return nil
            end

            # Clone the repo into a temp directory that will be automatically cleaned up.
            Dir.mktmpdir do |dir|
              return nil unless clone_repo(git, ref, dir, proxy)

              # Extract the name from the metadata file and calculate the SHA.
              Dir.chdir(dir) do
                [request_name(git, ref), request_sha(git, ref)]
              end
            end
          end

          # Requests a module's metadata and returns the name from it.
          #
          # @param git [String] The URL to the git repo.
          # @param ref [String] The ref to checkout.
          #
          private_class_method def self.request_name(git, ref)
            command = %W[git show #{ref}:metadata.json]
            Bolt::Logger.debug("Executing command '#{command.join(' ')}'")

            out, err, status = Open3.capture3(*command)

            unless status.success?
              raise Bolt::Error.new(
                "Unable to find metadata file at #{git}: #{err}",
                "bolt/missing-metadata-file-error"
              )
            end

            Bolt::Logger.debug("Found metadata file at #{git}")
            parse_name_from_metadata(out)
          end

          # Requests the SHA for the specified ref.
          #
          # @param git [String] The URL to the git repo.
          # @param ref [String] The ref to checkout.
          #
          private_class_method def self.request_sha(git, ref)
            command = %W[git rev-parse #{ref}^{commit}]
            Bolt::Logger.debug("Executing command '#{command.join(' ')}'")

            out, err, status = Open3.capture3(*command)

            if status.success?
              out.strip
            else
              raise Bolt::Error.new(
                "Unable to calculate SHA for ref #{ref} at #{git}: #{err}",
                "bolt/invalid-ref-error"
              )
            end
          end

          # Clones the repository. First attempts to clone a bare repository
          # and falls back to cloning the full repository if that fails. Cloning
          # a bare repository is significantly faster for large modules, but
          # cloning a bare repository using a commit is not supported.
          #
          # @param git [String] The URL to the git repo.
          # @param ref [String] The ref to checkout.
          # @param dir [String] The directory to clone the repo to.
          # @param proxy [String] The proxy to use when cloning.
          #
          private_class_method def self.clone_repo(git, ref, dir, proxy)
            clone  = %W[git clone #{git} #{dir}]
            clone += %W[--config "http.proxy=#{proxy}" --config "https.proxy=#{proxy}"] if proxy

            bare_clone = clone + %w[--bare --depth=1]
            bare_clone.push("--branch=#{ref}") unless ref == 'HEAD'

            # Attempt to clone a bare repository
            Bolt::Logger.debug("Executing command '#{bare_clone.join(' ')}'")
            _out, err, status = Open3.capture3(*bare_clone)
            return true if status.success?
            Bolt::Logger.debug("Unable to clone bare repository at #{loc(git, proxy)}: #{err}")

            # Fall back to cloning the full repository
            Bolt::Logger.debug("Executing command '#{clone.join(' ')}'")
            _out, err, status = Open3.capture3(*clone)
            Bolt::Logger.debug("Unable to clone repository at #{loc(git, proxy)}: #{err}") unless status.success?
            status.success?
          end

          # Returns true if the 'git' executable is available.
          #
          private_class_method def self.git?
            Open3.capture3('git', '--version')
            true
          rescue Errno::ENOENT
            false
          end
        end
      end
    end
  end
end
