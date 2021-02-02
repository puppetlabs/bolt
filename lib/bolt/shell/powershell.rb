# frozen_string_literal: true

require 'bolt/shell/powershell/snippets'

module Bolt
  class Shell
    class Powershell < Shell
      DEFAULT_EXTENSIONS = Set.new(%w[.ps1 .rb .pp])
      PS_ARGS = %w[-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass].freeze

      def initialize(target, conn)
        super

        extensions = [target.options['extensions'] || []].flatten.map { |ext| ext[0] == '.' ? ext : '.' + ext }
        extensions += target.options['interpreters'].keys if target.options['interpreters']
        @extensions = DEFAULT_EXTENSIONS + extensions
        validate_ps_version
      end

      def validate_ps_version
        version = execute("$PSVersionTable.PSVersion.Major").stdout.string.chomp
        if !version.empty? && version.to_i < 3
          # This lets us know how many targets have Powershell 2, and lets the
          # user know how many targets they have with PS2
          msg = "Detected PowerShell 2 on one or more targets.\nPowerShell 2 "\
            "is unsupported. See bolt-debug.log or run with '--log-level debug' to see the full "\
            "list of targets with PowerShell 2."

          Bolt::Logger.deprecate_once("powershell_2", msg)
          @logger.debug("Detected PowerShell 2 on #{target}.")
        end
      end

      def provided_features
        ['powershell']
      end

      def default_input_method(executable)
        powershell_file?(executable) ? 'powershell' : 'both'
      end

      def powershell_file?(path)
        File.extname(path).downcase == '.ps1'
      end

      def validate_extensions(ext)
        unless @extensions.include?(ext)
          raise Bolt::Node::FileError.new("File extension #{ext} is not enabled, "\
                                          "to run it please add to 'winrm: extensions'", 'FILETYPE_ERROR')
        end
      end

      def process_from_extension(path)
        case Pathname(path).extname.downcase
        when '.rb'
          [
            'ruby.exe',
            %W[-S "#{path}"]
          ]
        when '.ps1'
          [
            'powershell.exe',
            [*PS_ARGS, '-File', path]
          ]
        when '.pp'
          [
            'puppet.bat',
            %W[apply "#{path}"]
          ]
        else
          # Run the script via cmd, letting Windows extension handling determine how
          [
            'cmd.exe',
            %W[/c "#{path}"]
          ]
        end
      end

      def escape_arguments(arguments)
        arguments.map do |arg|
          if arg =~ / /
            "\"#{arg}\""
          else
            arg
          end
        end
      end

      def env_declarations(env_vars)
        env_vars.map do |var, val|
          "[Environment]::SetEnvironmentVariable('#{var}', @'\n#{val}\n'@)"
        end
      end

      def quote_string(string)
        "'" + string.gsub("'", "''") + "'"
      end

      def write_executable(dir, file, filename = nil)
        filename ||= File.basename(file)
        validate_extensions(File.extname(filename))
        destination = "#{dir}\\#{filename}"
        conn.upload_file(file, destination)
        destination
      end

      def execute_process(path, arguments, stdin = nil)
        quoted_args = arguments.map { |arg| quote_string(arg) }.join(' ')

        quoted_path = if path =~ /^'.*'$/ || path =~ /^".*"$/
                        path
                      else
                        quote_string(path)
                      end
        exec_cmd =
          if stdin.nil?
            "& #{quoted_path} #{quoted_args}"
          else
            <<~STR
            $command_stdin = @'
            #{stdin}
            '@

            $command_stdin | & #{quoted_path} #{quoted_args}
            STR
          end
        Snippets.execute_process(exec_cmd)
      end

      def mkdirs(dirs)
        paths = dirs.uniq.sort.join('","')
        mkdir_command = "mkdir -Force -Path (\"#{paths}\")"
        result = execute(mkdir_command)
        if result.exit_code != 0
          message = "Could not create directories: #{result.stderr.string}"
          raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
        end
      end

      def make_tmpdir
        find_parent = target.options['tmpdir'] ? "\"#{target.options['tmpdir']}\"" : '[System.IO.Path]::GetTempPath()'
        result = execute(Snippets.make_tmpdir(find_parent))
        if result.exit_code != 0
          raise Bolt::Node::FileError.new("Could not make tmpdir: #{result.stderr.string}", 'TMPDIR_ERROR')
        end
        result.stdout.string.chomp
      end

      def rmdir(dir)
        execute(Snippets.rmdir(dir))
      end

      def with_tmpdir
        unless @tmpdir
          # Only cleanup the directory afterward if we made it to begin with
          owner = true
          @tmpdir = make_tmpdir
        end
        yield @tmpdir
      ensure
        if owner && @tmpdir
          if target.options['cleanup']
            rmdir(@tmpdir)
          else
            Bolt::Logger.warn("Skipping cleanup of tmpdir '#{@tmpdir}'", "skip_cleanup")
          end
        end
      end

      def run_ps_task(task_path, arguments, input_method)
        # NOTE: cannot redirect STDIN to a .ps1 script inside of PowerShell
        # must create new powershell.exe process like other interpreters
        # fortunately, using PS with stdin input_method should never happen
        if input_method == 'powershell'
          Snippets.ps_task(task_path, arguments)
        else
          Snippets.try_catch(task_path)
        end
      end

      def upload(source, destination, _options = {})
        conn.upload_file(source, destination)
        Bolt::Result.for_upload(target, source, destination)
      end

      def download(source, destination, _options = {})
        download = File.join(destination, Bolt::Util.windows_basename(source))
        conn.download_file(source, destination, download)
        Bolt::Result.for_download(target, source, destination, download)
      end

      def run_command(command, options = {}, position = [])
        command = [*env_declarations(options[:env_vars]), command].join("\r\n") if options[:env_vars]

        wrap_command = conn.is_a?(Bolt::Transport::Local::Connection)
        output = execute(command, wrap_command)
        Bolt::Result.for_command(target,
                                 output.stdout.string,
                                 output.stderr.string,
                                 output.exit_code,
                                 'command',
                                 command,
                                 position)
      end

      def run_script(script, arguments, options = {}, position = [])
        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)
        with_tmpdir do |dir|
          script_path = write_executable(dir, script)
          command = if powershell_file?(script_path)
                      Snippets.run_script(arguments, script_path)
                    else
                      path, args = *process_from_extension(script_path)
                      args += escape_arguments(arguments)
                      execute_process(path, args)
                    end
          command = [*env_declarations(options[:env_vars]), command].join("\r\n") if options[:env_vars]

          output = execute(command)
          Bolt::Result.for_command(target,
                                   output.stdout.string,
                                   output.stderr.string,
                                   output.exit_code,
                                   'script',
                                   script,
                                   position)
        end
      end

      def run_task(task, arguments, _options = {}, position = [])
        implementation = select_implementation(target, task)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']
        input_method ||= powershell_file?(executable) ? 'powershell' : 'both'

        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)
        with_tmpdir do |dir|
          if extra_files.empty?
            task_dir = dir
          else
            # TODO: optimize upload of directories
            arguments['_installdir'] = dir
            task_dir = File.join(dir, task.tasks_dir)
            mkdirs([task_dir] + extra_files.map { |file| File.join(dir, File.dirname(file['name'])) })
            extra_files.each do |file|
              conn.upload_file(file['path'], File.join(dir, file['name']))
            end
          end

          task_path = write_executable(task_dir, executable)

          if Bolt::Task::STDIN_METHODS.include?(input_method)
            stdin = JSON.dump(arguments)
          end

          command = if powershell_file?(task_path) && stdin.nil?
                      run_ps_task(task_path, arguments, input_method)
                    else
                      if (interpreter = select_interpreter(task_path, target.options['interpreters']))
                        path = interpreter
                        args = [task_path]
                      else
                        path, args = *process_from_extension(task_path)
                      end
                      execute_process(path, args, stdin)
                    end

          env_assignments = if Bolt::Task::ENVIRONMENT_METHODS.include?(input_method)
                              env_declarations(envify_params(arguments))
                            else
                              []
                            end

          output = execute([Snippets.shell_init, *env_assignments, command].join("\n"))

          Bolt::Result.for_task(target, output.stdout.string,
                                output.stderr.string,
                                output.exit_code,
                                task.name,
                                position)
        end
      end

      def execute(command, wrap_command = false)
        if (conn.max_command_length && command.length > conn.max_command_length) ||
           wrap_command
          return with_tmpdir do |dir|
            command += "\r\nif (!$?) { if($LASTEXITCODE) { exit $LASTEXITCODE } else { exit 1 } }"
            script_file = File.join(dir, "#{SecureRandom.uuid}_wrapper.ps1")
            conn.upload_file(StringIO.new(command), script_file)
            args = escape_arguments([script_file])
            script_invocation = ['powershell.exe', *PS_ARGS, '-File', *args].join(' ')
            execute(script_invocation)
          end
        end
        inp, out, err, t = conn.execute(command)

        result = Bolt::Node::Output.new
        inp.close
        stdout = Thread.new do
          # Set to binmode to preserve \r\n line endings, but save and restore
          # the proper encoding so the string isn't later misinterpreted
          encoding = out.external_encoding
          out.binmode
          result.stdout << out.read.force_encoding(encoding)
        end
        stderr = Thread.new do
          encoding = err.external_encoding
          err.binmode
          result.stderr << err.read.force_encoding(encoding)
        end

        stdout.join
        stderr.join
        result.exit_code = t.value.respond_to?(:exitstatus) ? t.value.exitstatus : t.value

        result
      end
    end
  end
end
