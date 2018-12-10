# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'tmpdir'
require 'bolt/transport/base'
require 'bolt/transport/powershell'
require 'bolt/util'

module Bolt
  module Transport
    class Local < Base
      def self.options
        %w[tmpdir]
      end

      def provided_features
        ['shell']
      end

      def default_input_method(executable)
        input_method ||= Powershell.powershell_file?(executable) ? 'powershell' : 'both'
        input_method
      end

      def self.validate(_options); end

      def initialize
        super
        @conn = Shell.new
      end

      def in_tmpdir(base)
        args = base ? [nil, base] : []
        Dir.mktmpdir(*args) do |dir|
          yield dir
        end
      rescue StandardError => e
        raise Bolt::Node::FileError.new("Could not make tempdir: #{e.message}", 'TEMPDIR_ERROR')
      end
      private :in_tmpdir

      def copy_file(source, destination)
        FileUtils.cp_r(source, destination, remove_destination: true)
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
          if Bolt::Util.windows?
            if Powershell.powershell_file?(file)
              command = Powershell.run_script(arguments, file)
              output = @conn.execute(command, dir: dir, env: "powershell.exe")
            else
              path, args = *Powershell.process_from_extension(file)
              args += Powershell.escape_arguments(arguments)
              command = args.unshift(path).join(' ')
              output = @conn.execute(command, dir: dir)
            end
          else
            if arguments.empty?
              # We will always provide separated arguments, so work-around Open3's handling of a single
              # argument as the entire command string for script paths containing spaces.
              arguments = ['']
            end
            output = @conn.execute(file, *arguments, dir: dir)
          end
          Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def run_task(target, task, arguments, _options = {})
        implementation = select_implementation(target, task)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']

        in_tmpdir(target.options['tmpdir']) do |dir|
          if extra_files.empty?
            script = File.join(dir, File.basename(executable))
          else
            arguments['_installdir'] = dir
            script_dest = File.join(dir, task.tasks_dir)
            FileUtils.mkdir_p([script_dest] + extra_files.map { |file| File.join(dir, File.dirname(file['name'])) })

            script = File.join(script_dest, File.basename(executable))
            extra_files.each do |file|
              dest = File.join(dir, file['name'])
              copy_file(file['path'], dest)
              File.chmod(0o750, dest)
            end
          end

          copy_file(executable, script)
          File.chmod(0o750, script)

          # log the arguments with sensitive data redacted, do NOT log unwrapped_arguments
          logger.debug("Running '#{script}' with #{arguments}")
          unwrapped_arguments = unwrap_sensitive_args(arguments)

          stdin = STDIN_METHODS.include?(input_method) ? JSON.dump(unwrapped_arguments) : nil

          if Bolt::Util.windows?
            # WINDOWS
            if ENVIRONMENT_METHODS.include?(input_method)
              environment_params = envify_params(unwrapped_arguments).each_with_object([]) do |(arg, val), list|
                list << Powershell.set_env(arg, val)
              end
              environment_params = environment_params.join("\n") + "\n"
            else
              environment_params = ""
            end

            output =
              if Powershell.powershell_file?(script) && stdin.nil?
                command = Powershell.run_ps_task(arguments, script, input_method)
                command = environment_params + Powershell.shell_init + command
                if input_method == 'powershell'
                  @conn.execute(command, dir: dir, env: "powershell.exe")
                else
                  @conn.execute(command, dir: dir, stdin: stdin, env: "powershell.exe")
                end
              else
                path, args = *Powershell.process_from_extension(script)
                command = args.unshift(path).join(' ')
                command = environment_params + Powershell.shell_init + command
                @conn.execute(command, dir: dir, stdin: stdin, env: "powershell.exe")
              end
          else
            # POSIX
            env = ENVIRONMENT_METHODS.include?(input_method) ? envify_params(unwrapped_arguments) : nil
            output = @conn.execute(script, stdin: stdin, env: env, dir: dir)
          end
          Bolt::Result.for_task(target, output.stdout.string, output.stderr.string, output.exit_code)
        end
      end

      def connected?(_targets)
        true
      end
    end
  end
end

require 'bolt/transport/local/shell'
