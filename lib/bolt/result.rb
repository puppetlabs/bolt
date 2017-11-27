require 'json'
require 'bolt/error'

module Bolt
  class Result
    attr_reader :message, :error

    def self.from_exception(exception)
      @exception = exception
      if @exception.is_a?(Bolt::Error)
        error = @exception.to_h
      else
        error = {
          'kind' => 'puppetlabs.tasks/exception-error',
          'issue_code' => 'EXCEPTION',
          'msg' => exception.message,
          'details' => { 'class' => exception.class.to_s }
        }
        error['details']['stack_trace'] = exception.backtrace.join('\n') if exception.backtrace
      end
      Result.new(error)
    end

    def initialize(error = nil, message = nil)
      @error = error
      @message = message
    end

    def value
      nil
    end

    def to_h
      h = {}
      if value
        h['value'] = value
        h['value']['_output'] = message if message
      elsif message
        h['value'] = { '_output' => message }
      end
      h['error'] = error if error
      h
    end

    def to_result
      # TODO: This should be to_h but we need to update the plan functions to
      # use this hash instead
      special_keys = {}
      special_keys['_error'] = error if error
      special_keys['_output'] = message if message
      val = value || {}
      val.merge(special_keys)
    end

    def success?
      error.nil?
    end
  end

  class CommandResult < Result
    attr_reader :stdout, :stderr, :exit_code

    def self.from_output(output)
      new(output.stdout.string,
          output.stderr.string,
          output.exit_code)
    end

    def initialize(stdout, stderr, exit_code)
      @stdout = stdout || ""
      @stderr = stderr || ""
      @exit_code = exit_code
    end

    def value
      {
        'stdout' => @stdout,
        'stderr' => @stderr,
        'exit_code' => @exit_code
      }
    end

    def success?
      @exit_code == 0
    end

    def error
      unless success?
        {
          'kind' => 'puppetlabs.tasks/command-error',
          'issue_code' => 'COMMAND_ERROR',
          'msg' => "The command failed with exit code #{@exit_code}",
          'details' => { 'exit_code' => @exit_code }
        }
      end
    end
  end

  class TaskResult < CommandResult
    attr_reader :value

    def initialize(stdout, stderr, exit_code)
      super(stdout, stderr, exit_code)
      @value = parse_output(stdout)
      @message = @value.delete('_output')
      @error = @value.delete('_error')
    end

    def error
      unless success?
        return @error if @error
        msg = if !@stdout.empty?
                "The task failed with exit code #{@exit_code}"
              else
                "The task failed with exit code #{@exit_code}:\n#{@stderr}"
              end
        { 'kind' => 'puppetlabs.tasks/task-error',
          'issue_code' => 'TASK_ERROR',
          'msg' => msg,
          'details' => { 'exit_code' => @exit_code } }
      end
    end

    private

    def parse_output(output)
      begin
        obj = JSON.parse(output)
        unless obj.is_a? Hash
          obj = nil
        end
      rescue JSON::ParserError
        obj = nil
      end
      obj || { '_output' => output }
    end
  end
end
