module Bolt
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

    def stdout
      @stdout ||=
        if @output && @output.stdout
          @output.stdout.rewind
          @output.stdout.read
        else
          ''
        end
    end

    def stderr
      @stderr ||=
        if @output && @output.stderr
          @output.stderr.rewind
          @output.stderr.read
        else
          ''
        end
    end

    # Converts the result into a hash according to the tasks spec
    def result_hash
      res = nil
      begin
        res = JSON.parse(stdout)
        if res.class != Hash
          res = nil
        end
      rescue JSON::ParserError
        res = nil
      end

      res ||= { '_output' => stdout }

      unless res['_error']
        err = error_as_hash
        res['_error'] = err if err
      end

      res
    end

    # Turns any error indication into a hash as described in the task
    # spec. If there was no error, returns +nil+
    def error_as_hash
      nil
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

    def print_to_stream(stream)
      if @output
        @output.stdout.rewind
        IO.copy_stream(@output.stdout, stream)
        @output.stderr.rewind
        IO.copy_stream(@output.stderr, stream)
      else
        stream.puts @value
      end
    end

    def colorize(stream)
      stream.print "\033[32m" if stream.isatty
      yield
      stream.print "\033[0m" if stream.isatty
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

    def print_to_stream(stream)
      if @output
        @output.stdout.rewind
        IO.copy_stream(@output.stdout, stream)
        @output.stderr.rewind
        IO.copy_stream(@output.stderr, stream)
      else
        stream.puts @value
      end
    end

    def colorize(stream)
      stream.print "\033[31m" if stream.isatty
      yield
      stream.print "\033[0m" if stream.isatty
    end

    def error_as_hash
      msg = "Task exited with #{@exit_code}"
      msg += "\n#{stderr}" if stdout.empty?
      {
        'kind' => 'task_error',
        'msg' => msg,
        'details' => { 'exit_code' => @exit_code }
      }
    end
  end

  class ExceptionFailure < Failure
    attr_reader :exception

    def initialize(exception)
      super(1, nil)
      @exception = exception
    end

    def print_to_stream(stream)
      stream.puts @exception.message
    end

    def error_as_hash
      # We assume here that ExceptionFailure is only used when we truly
      # encounter an exception, and that things like failing to connect, or
      # losing the connection is surfaced as another kind of failure. For
      # those failures, we really want +kind+ to indicate in more detail
      # what went wrong, and should not expose the exception class name to
      # callers as that is really an implementation detail
      {
        'kind' => 'task_exception',
        'msg' => exception.message,
        'details' => {
          'class' => exception.class.name,
          'backtrace' => exception.backtrace
        }
      }
    end
  end
end
