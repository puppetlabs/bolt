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
  end

  class Success < Result
    attr_reader :value

    def initialize(value = '', output = nil)
      super(output)
      @value = value
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
  end

  class Failure < Result
    attr_reader :exit_code

    def initialize(exit_code, output)
      super(output)
      @exit_code = exit_code
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
  end
end
