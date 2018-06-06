# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tmpdir'
require 'bolt/transport/base'
require 'bolt/result'
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
          Dir.chdir(dir) do
            yield dir
          end
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
          yield dest
        end
      end
      private :with_tmpscript

      def upload(target, source, destination, _options = {})
        copy_file(source, destination)
        Bolt::Result.for_upload(target, source, destination)
      end

      def run_command(target, command, _options = {})
        in_tmpdir(target.options['tmpdir']) do |_|
          output = @conn.execute(command, {})
          Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def run_script(target, script, arguments, _options = {})
        with_tmpscript(File.absolute_path(script), target.options['tmpdir']) do |file|
          logger.debug "Running '#{file}' with #{arguments}"

          if arguments.empty?
            # We will always provide separated arguments, so work-around Open3's handling of a single
            # argument as the entire command string for script paths containing spaces.
            arguments = ['']
          end
          output = @conn.execute(file, *arguments, {})
          Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def run_task(target, task, arguments, _options = {})
        executable = target.select_impl(task, PROVIDED_FEATURES)
        raise "No suitable implementation of #{task.name} for #{target.name}" unless executable

        input_method = task.input_method ? task.input_method : "both"
        stdin = STDIN_METHODS.include?(input_method) ? JSON.dump(arguments) : nil
        env = ENVIRONMENT_METHODS.include?(input_method) ? arguments : nil

        with_tmpscript(executable, target.options['tmpdir']) do |script|
          logger.debug("Running '#{script}' with #{arguments}")

          output = @conn.execute(script, stdin: stdin, env: env)
          Bolt::Result.for_task(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end
    end
  end
end

require 'bolt/transport/local/shell'
