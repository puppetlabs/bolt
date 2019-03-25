# frozen_string_literal: true

require 'json'
require 'bolt/error'

module Bolt
  class Result
    attr_reader :target, :value, :type, :object

    def self.from_exception(target, exception)
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
      Result.new(target, error: error)
    end

    def self.for_command(target, stdout, stderr, exit_code, type, command)
      value = {
        'stdout' => stdout,
        'stderr' => stderr,
        'exit_code' => exit_code
      }
      unless exit_code == 0
        value['_error'] = {
          'kind' => 'puppetlabs.tasks/command-error',
          'issue_code' => 'COMMAND_ERROR',
          'msg' => "The command failed with exit code #{exit_code}",
          'details' => { 'exit_code' => exit_code }
        }
      end
      new(target, value: value, type: type, object: command)
    end

    def self.for_task(target, stdout, stderr, exit_code, task)
      begin
        value = JSON.parse(stdout)
        unless value.is_a? Hash
          value = nil
        end
      rescue JSON::ParserError
        value = nil
      end
      value ||= { '_output' => stdout }
      if exit_code != 0 && value['_error'].nil?
        msg = if stdout.empty?
                "The task failed with exit code #{exit_code}:\n#{stderr}"
              else
                "The task failed with exit code #{exit_code}"
              end
        value['_error'] = { 'kind' => 'puppetlabs.tasks/task-error',
                            'issue_code' => 'TASK_ERROR',
                            'msg' => msg,
                            'details' => { 'exit_code' => exit_code } }
      end
      new(target, value: value, type: 'task', object: task)
    end

    def self.for_upload(target, source, destination)
      new(target, message: "Uploaded '#{source}' to '#{target.host}:#{destination}'", type: 'upload', object: source)
    end

    # Satisfies the Puppet datatypes API
    def self.from_asserted_args(target, value)
      new(target, value: value)
    end

    def initialize(target, error: nil, message: nil, value: nil, type: nil, object: nil)
      @target = target
      @value = value || {}
      @type = type
      @object = object
      @value_set = !value.nil?
      if error && !error.is_a?(Hash)
        raise "TODO: how did we get a string error"
      end
      @value['_error'] = error if error
      @value['_output'] = message if message
    end

    def message
      @value['_output']
    end

    def status_hash
      { node: @target.name,
        type: type,
        object: object,
        status: ok? ? 'success' : 'failure',
        result: @value }
    end

    def generic_value
      if @value_set
        value.reject { |k, _| %w[_error _output].include? k }
      end
    end

    def eql?(other)
      self.class == other.class &&
        target == other.target &&
        value == other.value
    end

    def [](key)
      value[key]
    end

    def ==(other)
      eql?(other)
    end

    def to_json(opts = nil)
      status_hash.to_json(opts)
    end

    def to_s
      to_json
    end

    def ok?
      error_hash.nil?
    end
    alias ok ok?
    alias success? ok?

    # This allows access to errors outside puppet compilation
    # it should be prefered over error in bolt code
    def error_hash
      value['_error']
    end

    # Warning: This will fail outside of a compilation.
    # Use error_hash inside bolt.
    # Is it crazy for this to behave differently outside a compiler?
    def error
      if error_hash
        Puppet::DataTypes::Error.from_asserted_hash(error_hash)

      end
    end
  end
end
