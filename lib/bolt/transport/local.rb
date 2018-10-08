# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tmpdir'
require 'bolt/transport/base'
require 'bolt/util'

module Bolt
  module Transport
    class Local < Base
      def self.options
        %w[tmpdir]
      end

      PROVIDED_FEATURES = ['shell'].freeze

      def self.validate(_options); end

      def initialize
        super

        if Bolt::Util.windows?
          raise NotImplementedError, "The local transport is not yet implemented on Windows"
        else
          @conn = Shell.new
        end
      end

      def in_tmpdir(base)
        args = base ? [nil, base] : []
        Dir.mktmpdir(*args) do |dir|
          yield dir
        end
      end
      private :in_tmpdir

      def copy_file(source, destination)
        FileUtils.copy_file(source, destination)
      rescue StandardError => e
        raise Bolt::Node::FileError.new(e.message, 'WRITE_ERROR')
      end

      def with_tmpscript(script, base)
        in_tmpdir(base) do |dir|
          dest = File.join(dir, File.basename(script))
          copy_file(script, dest)
          File.chmod(0o750, dest)
          yield dest, dir
        end
      end
      private :with_tmpscript

      def upload(target, source, destination, _options = {})
        copy_file(source, destination)
        Bolt::Result.for_upload(target, source, destination)
      end

      def run_command(target, command, _options = {})
        in_tmpdir(target.options['tmpdir']) do |dir|
          output = @conn.execute(command, dir: dir)
          Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def run_script(target, script, arguments, _options = {})
        with_tmpscript(File.absolute_path(script), target.options['tmpdir']) do |file, dir|
          logger.debug "Running '#{file}' with #{arguments}"

          # unpack any Sensitive data AFTER we log
          arguments = unwrap_sensitive_args(arguments)
          if arguments.empty?
            # We will always provide separated arguments, so work-around Open3's handling of a single
            # argument as the entire command string for script paths containing spaces.
            arguments = ['']
          end
          output = @conn.execute(file, *arguments, dir: dir)
          Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def run_task(target, task, arguments, _options = {})
        implementation = task.select_implementation(target, PROVIDED_FEATURES)
        executable = implementation['path']
        input_method = implementation['input_method'] || 'both'
        extra_files = implementation['files']

        with_tmpscript(executable, target.options['tmpdir']) do |script, dir|
          if extra_files
            installdir = File.join(dir, '_installdir')
            arguments['_installdir'] = installdir
            FileUtils.mkdir_p(extra_files.map { |file| File.join(installdir, File.dirname(file['name'])) })

            extra_files.each do |file|
              copy_file(file['path'], File.join(installdir, file['name']))
            end
          end

          # unpack any Sensitive data, write it to a separate variable because
          # we log 'arguments' below
          unwrapped_arguments = unwrap_sensitive_args(arguments)
          stdin = STDIN_METHODS.include?(input_method) ? JSON.dump(unwrapped_arguments) : nil
          env = ENVIRONMENT_METHODS.include?(input_method) ? envify_params(unwrapped_arguments) : nil

          # log the arguments with sensitive data redacted, do NOT log unwrapped_arguments
          logger.debug("Running '#{script}' with #{arguments}")

          output = @conn.execute(script, stdin: stdin, env: env, dir: dir)
          Bolt::Result.for_task(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end
    end
  end
end

require 'bolt/transport/local/shell'
