# frozen_string_literal: true

require 'bolt/logger'
require 'bolt/node/errors'
require 'bolt/transport/simple'

module Bolt
  module Transport
    class LXD < Simple
      def provided_features
        ['shell']
      end

      def with_connection(target, options = {})
        conn = Connection.new(target, options) # make "remote" another param?
        conn.connect
        yield conn
      end

     # def run_script(target, script, arguments, options = {}, position = [])
     #   # TODO, upload and execute
     # end

     # def run_task(target, task, arguments, _options = {}, position = [])
     #   # TODO
     #   implementation = task.select_implementation(target, provided_features)
     #   executable = implementation['path']
     #   input_method = implementation['input_method']
     #   extra_files = implementation['files']
     #   input_method ||= 'both'

     #   # unpack any Sensitive data
     #   arguments = unwrap_sensitive_args(arguments)

     #   with_connection(target) do |conn|
     #     execute_options = {}
     #     execute_options[:interpreter] = select_interpreter(executable, target.options['interpreters'])
     #     conn.with_remote_tmpdir do |dir|
     #       if extra_files.empty?
     #         task_dir = dir
     #       else
     #         # TODO: optimize upload of directories
     #         arguments['_installdir'] = dir
     #         task_dir = File.join(dir, task.tasks_dir)
     #         conn.mkdirs([task_dir] + extra_files.map { |file| File.join(dir, File.dirname(file['name'])) })
     #         extra_files.each do |file|
     #           conn.write_remote_file(file['path'], File.join(dir, file['name']))
     #         end
     #       end

     #       remote_task_path = conn.write_remote_executable(task_dir, executable)

     #       if Bolt::Task::STDIN_METHODS.include?(input_method)
     #         execute_options[:stdin] = StringIO.new(JSON.dump(arguments))
     #       end

     #       if Bolt::Task::ENVIRONMENT_METHODS.include?(input_method)
     #         execute_options[:environment] = envify_params(arguments)
     #       end

     #       stdout, stderr, exitcode = conn.execute(remote_task_path, execute_options)
     #       Bolt::Result.for_task(target,
     #                             stdout,
     #                             stderr,
     #                             exitcode,
     #                             task.name,
     #                             position)
     #     end
     #   end
     # end

    end
  end
end

require 'bolt/transport/lxd/exec_connection'
