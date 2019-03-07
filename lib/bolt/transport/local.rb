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
        %w[tmpdir interpreters sudo-password run-as run-as-command]
      end

      def self.default_options
        {
          'interpreters' => { '.rb' => RbConfig.ruby }
        }
      end

      def provided_features
        if Bolt::Util.windows?
          ['powershell']
        else
          ['shell']
        end
      end

      def default_input_method(executable)
        input_method ||= Powershell.powershell_file?(executable) ? 'powershell' : 'both'
        input_method
      end

      def self.validate(options)
        logger = Logging.logger[self]
        validate_sudo_options(options, logger)
      end

      def initialize
        super
        @conn = Shell.new
      end

      def in_tmpdir(base)
        args = base ? [nil, base] : []
        dir = begin
                Dir.mktmpdir(*args)
              rescue StandardError => e
                raise Bolt::Node::FileError.new("Could not make tempdir: #{e.message}", 'TEMPDIR_ERROR')
              end

        yield dir
      ensure
        FileUtils.remove_entry dir if dir
      end
      private :in_tmpdir

      def chown(owner, filepaths)
        # I kept this separate from SSH::Connection::RemoteTempdir
        # to make use of fileutils
        # The logic is similar though
        return if owner.nil? || owner == Etc.getlogin
        result = `id -g #{owner}`
        if result.exit_code != 0
          message = "Could not identify group of user #{owner}: #{result.stderr.string}"
          raise Bolt::Node::FileError.new(message, 'ID_ERROR')
        end
        group = result.stdout.string.chomp

        result = FileUtils.chown_R(owner, group, filepaths)
        if result.exit_code != 0
          message = "Could not change owner of '#{@path}' to #{owner}: #{result.stderr.string}"
          raise Bolt::Node::FileError.new(message, 'CHOWN_ERROR')
        end
      end

      def copy_file(source, destination)
        chown(@conn.run_as, source)
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

      def upload(target, source, destination, options = {})
        @conn.running_as(options['_run_as']) do
          copy_file(source, destination)
          Bolt::Result.for_upload(target, source, destination)
        end
      end

      def run_command(target, command, options = {})
        @conn.running_as(options['_run_as']) do
          in_tmpdir(target.options['tmpdir']) do |dir|
            options[:sudoable] = true if @conn.run_as
            options[:dir] = dir
            output = @conn.execute(command, target.options, options)
            Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
          end
        end
      end

      def run_script(target, script, arguments, options = {})
        @conn.running_as(options['_run_as']) do
          with_tmpscript(File.absolute_path(script), target.options['tmpdir']) do |file, dir|
            logger.debug "Running '#{file}' with #{arguments}"

            # unpack any Sensitive data AFTER we log
            arguments = unwrap_sensitive_args(arguments)
            if Bolt::Util.windows?
              if Powershell.powershell_file?(file)
                command = Powershell.run_script(arguments, file)
                output = @conn.execute(command, target.options, dir: dir, env: "powershell.exe")
              else
                path, args = *Powershell.process_from_extension(file)
                args += Powershell.escape_arguments(arguments)
                command = args.unshift(path).join(' ')
                output = @conn.execute(command, target.options, dir: dir)
              end
            else
              if arguments.empty?
                # We will always provide separated arguments, so work-around Open3's handling of a single
                # argument as the entire command string for script paths containing spaces.
                arguments = ['']
              end
              output = @conn.execute(file, target.options, *arguments, dir: dir)
            end
            Bolt::Result.for_command(target, output.stdout.string, output.stderr.string, output.exit_code)
          end
        end
      end

      def run_task(target, task, arguments, options = {})
        implementation = select_implementation(target, task)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']

        @conn.running_as(options['_run_as']) do
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

            interpreter = select_interpreter(script, target.options['interpreters'])
            interpreter_debug = interpreter ? " using '#{interpreter}' interpreter" : nil
            # log the arguments with sensitive data redacted, do NOT log unwrapped_arguments
            logger.debug("Running '#{script}' with #{arguments}#{interpreter_debug}")
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

              if Powershell.powershell_file?(script) && stdin.nil?
                command = Powershell.run_ps_task(arguments, script, input_method)
                command = environment_params + Powershell.shell_init + command
                interpreter ||= 'powershell.exe'
                output =
                  if input_method == 'powershell'
                    @conn.execute(command, target.options, dir: dir, interpreter: interpreter)
                  else
                    @conn.execute(command, target.options, dir: dir, stdin: stdin, interpreter: interpreter)
                  end
              end
              unless output
                if interpreter
                  env = ENVIRONMENT_METHODS.include?(input_method) ? envify_params(unwrapped_arguments) : nil
                  output = @conn.execute(script, target.options, stdin: stdin, env: env, dir: dir, interpreter: interpreter)
                else
                  path, args = *Powershell.process_from_extension(script)
                  command = args.unshift(path).join(' ')
                  command = environment_params + Powershell.shell_init + command
                  output = @conn.execute(command, target.options, dir: dir, stdin: stdin, interpreter: 'powershell.exe')
                end
              end
            else
              # POSIX
              env = ENVIRONMENT_METHODS.include?(input_method) ? envify_params(unwrapped_arguments) : nil
              output = @conn.execute(script, target.options, stdin: stdin, environment: env, dir: dir, interpreter: interpreter)
            end
            Bolt::Result.for_task(target, output.stdout.string, output.stderr.string, output.exit_code)
          end
        end
      end

      def connected?(_targets)
        true
      end
    end
  end
end

require 'bolt/transport/local/shell'
