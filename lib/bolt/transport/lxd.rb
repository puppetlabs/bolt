# frozen_string_literal: true

require 'bolt/logger'
require 'bolt/node/errors'
require 'bolt/transport/simple'

module Bolt
  module Transport
    class LXD < Base
      def provided_features
        ['shell']
      end

      def with_connection(target)
        conn = ExecConnection.new(target) # make "remote" another param?
        conn.connect
        yield conn
      end

      def self.validate(options)
        if (url = options['service-url'])
          unless url.instance_of?(String)
            raise Bolt::ValidationError, 'service-url must be a string'
          end
        end
      end

      def upload(target, source, destination, _options = {})
        with_connection(target) do |conn|
          if File.directory?(source)
            conn.write_remote_directory(source, destination)
          else
            conn.write_remote_file(source, destination)
          end
          Bolt::Result.for_upload(target, source, destination)
        end
      end

      def download(target, source, destination, _options = {})
        with_connection(target) do |conn|
          download = File.join(destination, Bolt::Util.unix_basename(source))
          _stdout_str, stderr_str, status = conn.download_file(source, destination)
          unless status.exitstatus.zero?
            raise "Error downloading content from container #{target}: #{stderr_str}"
          end
          Bolt::Result.for_download(target, source, destination, download)
        end
      end

      def run_command(target, command, _options = {}, position = [])
        with_connection(target) do |conn|
          # TODO: what about
          # * environment variables
          # * "run as" user (lxc supports this)
          execute_options = {}
          stdout_str, stderr_str, exitcode = conn.execute(*Shellwords.split(command), execute_options)
          Bolt::Result.for_command(target, stdout_str, stderr_str, exitcode, 'command', command, position)
        end
      end

      def run_script(target, script, arguments, options = {}, position = [])
        # TODO, upload and execute
      end

      def run_task(target, task, arguments, _options = {}, position = [])
        # TODO
        implementation = task.select_implementation(target, provided_features)
        executable = implementation['path']
        input_method = implementation['input_method']
        extra_files = implementation['files']
        input_method ||= 'both'

        # unpack any Sensitive data
        arguments = unwrap_sensitive_args(arguments)

        with_connection(target) do |conn|
          execute_options = {}
          execute_options[:interpreter] = select_interpreter(executable, target.options['interpreters'])
          conn.with_remote_tmpdir do |dir|
            if extra_files.empty?
              task_dir = dir
            else
              # TODO: optimize upload of directories
              arguments['_installdir'] = dir
              task_dir = File.join(dir, task.tasks_dir)
              conn.mkdirs([task_dir] + extra_files.map { |file| File.join(dir, File.dirname(file['name'])) })
              extra_files.each do |file|
                conn.write_remote_file(file['path'], File.join(dir, file['name']))
              end
            end

            remote_task_path = conn.write_remote_executable(task_dir, executable)

            if Bolt::Task::STDIN_METHODS.include?(input_method)
              execute_options[:stdin] = StringIO.new(JSON.dump(arguments))
            end

            if Bolt::Task::ENVIRONMENT_METHODS.include?(input_method)
              execute_options[:environment] = envify_params(arguments)
            end

            stdout, stderr, exitcode = conn.execute(remote_task_path, execute_options)
            Bolt::Result.for_task(target,
                                  stdout,
                                  stderr,
                                  exitcode,
                                  task.name,
                                  position)
          end
        end
      end

      def connected?(target)
        with_connection(target) { true }
      rescue Bolt::Node::ConnectError
        false
      end
    end
  end
end

require 'bolt/transport/lxd/exec_connection'
