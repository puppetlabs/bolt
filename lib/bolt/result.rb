require 'json'

module Bolt
  class Result
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def value
      nil
    end

    def error
      nil
    end

    def to_h
      { 'value' => value }
    end

    def to_result
      value
    end

    def success?
      true
    end
  end

  class ErrorResult < Result
    def initialize(message, issue_code, kind)
      super(message)
      @issue_code = issue_code
      @kind = kind
    end

    def to_h
      {
        'error' => {
          'issue_code' => @issue_code,
          'kind' => @kind,
          'msg' => @message
        }
      }
    end

    def to_result
      {
        '_error' => {
          'issue_code' => @issue_code,
          'kind' => @kind,
          'msg' => @message
        }
      }
    end

    def success?
      false
    end
  end

  class CommandResult < Result
    attr_reader :stdout, :stderr, :exit_code

    def initialize(stdout, stderr, exit_code)
      @stdout = stdout
      @stderr = stderr
      @exit_code = exit_code
    end

    def value
      {
        'stdout' => @stdout,
        'stderr' => @stderr,
        'exit_code' => @exit_code
      }
    end

    def to_result
      value
    end

    def success?
      @exit_code.zero?
    end

    def message
      [stdout, stderr].join("\n")
    end
  end

  class TaskResult < CommandResult
    attr_reader :error

    def initialize(stdout, stderr, exit_code)
      super(stdout, stderr, exit_code)
      @object = output_to_json_hash(stdout)
      @error = @object.delete('_error') if @object
    end

    def value
      @object || @stdout
    end

    def to_result
      result = @object
      result['_error'] = @error if @error
      result
    end

    def to_h
      hash = super
      hash['error'] = error if error
      hash
    end

    private

    def output_to_json_hash(output)
      begin
        obj = JSON.parse(output)
        unless obj.is_a? Hash
          obj = nil
        end
      rescue JSON::ParserError
        nil
      end
      obj || { '_output' => output }
    end
  end

  class TaskSuccess < TaskResult
    def success?
      true
    end
  end

  class TaskFailure < TaskResult
    def initialize(stdout, stderr, exit_code)
      super(stdout, stderr, exit_code)
      @error ||= generate_error
    end

    def success?
      false
    end

    private

    def generate_error
      {
        'kind' => 'puppetlabs.tasks/task-error',
        'issue_code' => 'TASK_ERROR',
        'msg' => "The task failed with exit code #{@exit_code}",
        'details' => { 'exit_code' => @exit_code }
      }
    end
  end

  class ExceptionResult < Result
    def initialize(exception)
      @exception = exception
    end

    def error
      {
        'kind' => 'puppetlabs.tasks/exception-error',
        'issue_code' => 'EXCEPTION',
        'msg' => @exception.message,
        'details' => { 'stack_trace' => @exception.backtrace.join('\n') }
      }
    end

    def to_h
      { 'error' => error }
    end

    def message
      @exception.message
    end

    def success?
      false
    end
  end
end
