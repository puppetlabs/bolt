# frozen_string_literal: true

require 'bolt/shell/powershell/snippets'

module Bolt
  class Shell
    class Powershell < Shell
      DEFAULT_EXTENSIONS = Set.new(%w[.ps1 .rb .pp])

      def initialize(target, conn)
        super

        extensions = [target.options['extensions'] || []].flatten.map { |ext| ext[0] != '.' ? '.' + ext : ext }
        extensions += target.options['interpreters'].keys if target.options['interpreters']
        @extensions = DEFAULT_EXTENSIONS + extensions
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
            %W[-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass -File "#{path}"]
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

      def set_env(arg, val)
        cmd = "[Environment]::SetEnvironmentVariable('#{arg}', @'\n#{val}\n'@)"
        result = conn.execute(cmd)
        if result.exit_code != 0
          raise Bolt::Node::EnvironmentVarError.new(arg, val)
        end
      end

      def quote_string(string)
        "'" + string.gsub("'", "''") + "'"
      end

      def write_executable(dir, file, filename = nil)
        filename ||= File.basename(file)
        validate_extensions(File.extname(filename))
        remote_path = "#{dir}\\#{filename}"
        conn.copy_file(file, remote_path)
        remote_path
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
            "@'\n#{stdin}\n'@ | & #{quoted_path} #{quoted_args}"
          end
        Snippets.execute_process(exec_cmd)
      end

      def mkdirs(dirs)
        mkdir_command = "mkdir -Force #{dirs.uniq.sort.join(',')}"
        result = conn.execute(mkdir_command)
        if result.exit_code != 0
          message = "Could not create directories: #{result.stderr}"
          raise Bolt::Node::FileError.new(message, 'MKDIR_ERROR')
        end
      end

      def make_tempdir
        find_parent = target.options['tmpdir'] ? "\"#{target.options['tmpdir']}\"" : '[System.IO.Path]::GetTempPath()'
        result = conn.execute(Snippets.make_tempdir(find_parent))
        if result.exit_code != 0
          raise Bolt::Node::FileError.new("Could not make tempdir: #{result.stderr}", 'TEMPDIR_ERROR')
        end
        result.stdout.string.chomp
      end

      def rmdir(dir)
        conn.execute(Snippets.rmdir(dir))
      end

      def with_remote_tempdir
        dir = make_tempdir
        yield dir
      ensure
        rmdir(dir)
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

      def shell_init
        result = conn.execute(Snippets.shell_init)
        if result.exit_code != 0
          raise BaseError.new("Could not initialize shell: #{result.stderr.string}", "SHELL_INIT_ERROR")
        end
      end

      def upload(source, destination, _options = {})
        conn.copy_file(source, destination)
        Bolt::Result.for_upload(target, source, destination)
      end

      def run_command(command, _options = {})
        output = conn.execute(command)
        Bolt::Result.for_command(target,
                                 output.stdout.string,
                                 output.stderr.string,
                                 output.exit_code,
                                 'command', command)
      end

      def run_script(script, arguments, _options = {})
        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)
        with_remote_tempdir do |dir|
          remote_path = write_executable(dir, script)
          if powershell_file?(remote_path)
            output = conn.execute(Snippets.run_script(arguments, remote_path))
          else
            path, args = *process_from_extension(remote_path)
            args += escape_arguments(arguments)
            output = execute_process(path, args)
          end
          Bolt::Result.for_command(target,
                                   output.stdout.string,
                                   output.stderr.string,
                                   output.exit_code,
                                   'script', script)
        end
      end

      def run_task(task, arguments, _options = {})
        implementation = select_implementation(target, task)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']
        input_method ||= powershell_file?(executable) ? 'powershell' : 'both'

        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)
        with_remote_tempdir do |dir|
          if extra_files.empty?
            task_dir = dir
          else
            # TODO: optimize upload of directories
            arguments['_installdir'] = dir
            task_dir = File.join(dir, task.tasks_dir)
            mkdirs([task_dir] + extra_files.map { |file| File.join(dir, File.dirname(file['name'])) })
            extra_files.each do |file|
              conn.copy_file(file['path'], File.join(dir, file['name']))
            end
          end

          remote_task_path = write_executable(task_dir, executable)

          shell_init

          if Bolt::Task::STDIN_METHODS.include?(input_method)
            stdin = JSON.dump(arguments)
          end

          command = String.new

          if Bolt::Task::ENVIRONMENT_METHODS.include?(input_method)
            envify_params(arguments).each do |(arg, val)|
              command << set_env(arg, cal)
            end
          end

          output =
            if powershell_file?(remote_task_path) && stdin.nil?
              command << run_ps_task(remote_task_path, arguments, input_method)
              conn.execute(command)
            else
              if (interpreter = select_interpreter(remote_task_path, target.options['interpreters']))
                path = interpreter
                args = [remote_task_path]
              else
                path, args = *process_from_extension(remote_task_path)
              end
              command << execute_process(path, args, stdin)
              conn.execute(command)
            end

          Bolt::Result.for_task(target, output.stdout.string,
                                output.stderr.string,
                                output.exit_code,
                                task.name)
        end
      end

    end
  end
end
