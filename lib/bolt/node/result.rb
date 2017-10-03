require 'json'
require 'bolt/result'

module Bolt
  class Node
    class ResultOutput
      attr_reader :stdout, :stderr

      def initialize
        @stdout = StringIO.new
        @stderr = StringIO.new
      end
    end

    class Result
      attr_reader :output

      def initialize(output)
        @output = output
      end

      def output_string
        str = StringIO.new
        print_to_stream(str)
        str.string
      end

      def to_result
        Bolt::Result.new
      end

      def to_command_result
        Bolt::CommandResult.new(output.stdout.string,
                                output.stderr.string,
                                exit_code)
      end

      def exit_code
        0
      end
    end

    class Success < Result
      attr_reader :value

      def initialize(value = '', output = nil)
        super(output)
        @value = value
      end

      def success?
        true
      end

      def then
        yield @value
      end

      def to_task_result
        Bolt::TaskSuccess.new(output.stdout.string,
                              output.stderr.string,
                              exit_code)
      end
    end

    class Failure < Result
      attr_reader :exit_code

      def initialize(exit_code, output)
        super(output)
        @exit_code = exit_code
      end

      def success?
        false
      end

      def then
        self
      end

      def to_task_result
        Bolt::TaskFailure.new(output.stdout.string,
                              output.stderr.string,
                              exit_code)
      end
    end

    class ExceptionFailure < Failure
      attr_reader :exception

      def initialize(exception)
        super(1, nil)
        @exception = exception
      end

      def to_result
        Bolt::ExceptionResult.new(@exception)
      end

      def to_task_result
        to_result
      end

      def to_command_result
        to_result
      end
    end
  end
end
