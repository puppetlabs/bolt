# frozen_string_literal: true

require 'logging'
require_relative '../../bolt/result'

module Bolt
  module Transport
    # This class provides the default behavior for Transports. A Transport is
    # responsible for uploading files and running commands, scripts, and tasks
    # on Targets.
    #
    # Bolt executes work on the Transport in "batches". To do that, it calls
    # the batches() method, which is responsible for dividing the list of
    # Targets into batches according to how it wants to handle them. It will
    # then call Transport#batch_task, or the corresponding method for another
    # operation, passing a list of Targets. The Transport returns a list of
    # Bolt::Result objects, one per Target. Each batch is executed on a
    # separate thread, controlled by the `concurrency` setting, so many batches
    # may be running in parallel.
    #
    # The default batch implementation splits the list of Targets into batches
    # of 1. It then calls run_task(), or a corresponding method for other
    # operations, passing in the single Target.
    #
    # Most Transport implementations, like the SSH and WinRM transports, don't
    # need to do their own batching, since they only operate on a single Target
    # at a time. Those Transports can implement the run_task() and related
    # methods, which will automatically handle running many Targets in
    # parallel, and will handle publishing start and finish events for each
    # Target.
    #
    # Transports that need their own batching, like the Orch transport, can
    # instead override the batches() method to split Targets into sets that can
    # be executed together, and override the batch_task() and related methods
    # to execute a batch of targets. In that case, those Transports should accept
    # a block argument and call it with a :node_start event for each Target
    # before executing, and a :node_result event for each Target after
    # execution.
    class Base
      attr_reader :logger

      def initialize
        @logger = Bolt::Logger.logger(self)
      end

      def with_events(target, callback, action, position)
        callback&.call(type: :node_start, target: target)

        result = begin
          yield
        rescue StandardError, NotImplementedError => e
          Bolt::Result.from_exception(target, e, action: action, position: position)
        end

        callback&.call(type: :node_result, result: result)
        result
      end

      def provided_features
        []
      end

      def default_input_method(_executable)
        'both'
      end

      def select_implementation(target, task)
        impl = task.select_implementation(target, provided_features)
        impl['input_method'] ||= default_input_method(impl['path'])
        impl
      end

      def select_interpreter(executable, interpreters)
        interpreters[Pathname(executable).extname] if interpreters
      end

      # Raises an error if more than one target was given in the batch.
      #
      # The default implementations of batch_* strictly assume the transport is
      # using the default batch size of 1. This method ensures that is the
      # case and raises an error if it's not.
      def assert_batch_size_one(method, targets)
        if targets.length > 1
          message = "#{self.class.name} must implement #{method} to support batches (got #{targets.length} targets)"
          raise NotImplementedError, message
        end
      end

      # Runs the given task on a batch of targets.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implement their own batch processing.
      def batch_task(targets, task, arguments, options = {}, position = [], &callback)
        assert_batch_size_one("batch_task()", targets)
        target = targets.first
        with_events(target, callback, 'task', position) do
          @logger.debug { "Running task '#{task.name}' on #{target.safe_name}" }
          run_task(target, task, arguments, options, position)
        end
      end

      # Runs the given task on a batch of targets with variable parameters.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implment their own batch processing.
      def batch_task_with(targets, task, target_mapping, options = {}, position = [], &callback)
        assert_batch_size_one("batch_task_with()", targets)
        target = targets.first
        arguments = target_mapping[target]

        with_events(target, callback, 'task', position) do
          @logger.debug { "Running task '#{task.name}' on #{target.safe_name} with '#{arguments.to_json}'" }
          run_task(target, task, arguments, options, position)
        end
      end

      # Runs the given command on a batch of targets.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implement their own batch processing.
      def batch_command(targets, command, options = {}, position = [], &callback)
        assert_batch_size_one("batch_command()", targets)
        target = targets.first
        with_events(target, callback, 'command', position) do
          @logger.debug("Running command '#{command}' on #{target.safe_name}")
          run_command(target, command, options, position)
        end
      end

      # Runs the given script on a batch of targets.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implement their own batch processing.
      def batch_script(targets, script, arguments, options = {}, position = [], &callback)
        assert_batch_size_one("batch_script()", targets)
        target = targets.first
        with_events(target, callback, 'script', position) do
          @logger.debug { "Running script '#{script}' on #{target.safe_name}" }
          run_script(target, script, arguments, options, position)
        end
      end

      # Uploads the given source file to the destination location on a batch of targets.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implement their own batch processing.
      def batch_upload(targets, source, destination, options = {}, position = [], &callback)
        assert_batch_size_one("batch_upload()", targets)
        target = targets.first
        with_events(target, callback, 'upload', position) do
          @logger.debug { "Uploading: '#{source}' to #{destination} on #{target.safe_name}" }
          upload(target, source, destination, options)
        end
      end

      # Downloads the given source file from a batch of targets to the destination location
      # on the host.
      #
      # The default implementation only supports batches of size 1 and will fail otherwise.
      #
      # Transports may override this method to implement their own batch processing.
      def batch_download(targets, source, destination, options = {}, position = [], &callback)
        require 'erb'

        assert_batch_size_one("batch_download()", targets)
        target = targets.first
        with_events(target, callback, 'download', position) do
          escaped_name = ERB::Util.url_encode(target.safe_name)
          target_destination = File.expand_path(escaped_name, destination)
          @logger.debug { "Downloading: '#{source}' on #{target.safe_name} to #{target_destination}" }
          download(target, source, target_destination, options)
        end
      end

      def batch_connected?(targets)
        assert_batch_size_one("connected?()", targets)
        connected?(targets.first)
      end

      # Split the given list of targets into a list of batches. The default
      # implementation returns single-target batches.
      #
      # Transports may override this method, and the corresponding batch_*
      # methods, to implement their own batch processing.
      def batches(targets)
        targets.map { |target| [target] }
      end

      # Transports should override this method with their own implementation of running a command.
      def run_command(*_args)
        raise NotImplementedError, "run_command() must be implemented by the transport class"
      end

      # Transports should override this method with their own implementation of running a script.
      def run_script(*_args)
        raise NotImplementedError, "run_script() must be implemented by the transport class"
      end

      # Transports should override this method with their own implementation of running a task.
      def run_task(*_args)
        raise NotImplementedError, "run_task() must be implemented by the transport class"
      end

      # Transports should override this method with their own implementation of file upload.
      def upload(*_args)
        raise NotImplementedError, "upload() must be implemented by the transport class"
      end

      # Transports should override this method with their own implementation of file download.
      def download(*_args)
        raise NotImplementedError, "download() must be implemented by the transport class"
      end

      # Transports should override this method with their own implementation of a connection test.
      def connected?(_targets)
        raise NotImplementedError, "connected?() must be implemented by the transport class"
      end

      # Unwraps any Sensitive data in an arguments Hash, so the plain-text is passed
      # to the Task/Script.
      #
      # This works on deeply nested data structures composed of Hashes, Arrays, and
      # and plain-old data types (int, string, etc).
      def unwrap_sensitive_args(arguments)
        # Skip this if Puppet isn't loaded
        return arguments unless defined?(Puppet::Pops::Types::PSensitiveType::Sensitive)

        case arguments
        when Array
          # iterate over the array, unwrapping all elements
          arguments.map { |x| unwrap_sensitive_args(x) }
        when Hash
          # iterate over the arguments hash and unwrap all keys and values
          arguments.each_with_object({}) { |(k, v), h|
            h[unwrap_sensitive_args(k)] = unwrap_sensitive_args(v)
          }
        when Puppet::Pops::Types::PSensitiveType::Sensitive
          # this value is Sensitive, unwrap it
          unwrap_sensitive_args(arguments.unwrap)
        else
          # unknown data type, just return it
          arguments
        end
      end
    end
  end
end
