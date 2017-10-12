require 'json'
require 'open3'
require 'bolt/node/result'

module Bolt
  class Local < Node
    def connect
      # this is a local connection, just passing there...
    end

    def disconnect
      # this is a local connection, just passing there...
    end

    def execute(command, options = {})
      result_output = Bolt::Node::ResultOutput.new
      status = {}

      @logger.debug { "Executing: #{command}" }

      if options[:stdin]
        stdout, stderr, rc = Open3.capture3(command, :stdin_data => options[:stdin])
      else
        stdout, stderr, rc = Open3.capture3(command)
      end

      result_output.stdout << stdout.strip unless stdout.nil?
      @logger.debug { "stdout: #{data}" }

      result_output.stderr << stderr.strip unless stderr.nil?
      @logger.debug { "stderr: #{data}" }

      status[:exit_code] = rc.to_i

      if status[:exit_code].zero?
        @logger.debug { "Command returned successfully" }
        Bolt::Node::Success.new(result_output.stdout.string, result_output)
      else
        @logger.info { "Command failed with exit code #{status[:exit_code]}" }
        Bolt::Node::Failure.new(status[:exit_code], result_output)
      end
    end

    def _upload(source, destination)
      FileUtils.copy_file(source, destination)
      Bolt::Node::Success.new
    rescue StandardError => e
      Bolt::Node::ExceptionFailure.new(e)
    end

    def make_tempdir
      # Note(riton): Should be developed to support os that does not have mktemp
      Bolt::Node::Success.new(`mktemp -d`.chomp)
    rescue StandardError => e
      Bolt::Node::ExceptionFailure.new(e)
    end

    def with_remote_file(file)
      local_path = ''
      dir = ''
      result = nil

      make_tempdir.then do |value|
        dir = value
        local_path = "#{dir}/#{File.basename(file)}"
        Bolt::Node::Success.new
      end.then do
        _upload(file, local_path)
      end.then do
        execute("chmod u+x '#{local_path}'")
      end.then do
        result = yield local_path
      end.then do
        execute("rm -f '#{local_path}'")
      end.then do
        execute("rmdir '#{dir}'")
        result
      end
    end

    def _run_command(command)
      execute(command)
    end

    def _run_script(script)
      @logger.info { "Running script '#{script}'" }
      execute(script)
    end

    def _run_task(task, input_method, arguments)
      export_args = {}
      stdin = nil

      @logger.info { "Running task '#{task}'" }
      @logger.debug { "arguments: #{arguments}\ninput_method: #{input_method}" }

      if STDIN_METHODS.include?(input_method)
        stdin = JSON.dump(arguments)
      end

      if ENVIRONMENT_METHODS.include?(input_method)
        export_args = arguments.map do |env, val|
          "PT_#{env}='#{val}'"
        end.join(' ')
      end

      with_remote_file(task) do |remote_path|
        command = if export_args.empty?
                    "'#{remote_path}'"
                  else
                    "export #{export_args} && '#{remote_path}'"
                  end
        execute(command, stdin: stdin)
      end
    end
  end
end
