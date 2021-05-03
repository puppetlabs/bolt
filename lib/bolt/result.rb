# frozen_string_literal: true

require 'json'
require 'bolt/error'

module Bolt
  class Result
    attr_reader :target, :value, :action, :object

    def self.from_exception(target, exception, action: 'action', position: [])
      details = create_details(position)
      if exception.is_a?(Bolt::Error)
        error = Bolt::Util.deep_merge({ 'details' => details }, exception.to_h)
      else
        details['class'] = exception.class.to_s
        error = {
          'kind' => 'puppetlabs.tasks/exception-error',
          'issue_code' => 'EXCEPTION',
          'msg' => exception.message,
          'details' => details
        }
        error['details']['stack_trace'] = exception.backtrace.join('\n') if exception.backtrace
      end
      Result.new(target, error: error, action: action)
    end

    def self.create_details(position)
      %w[file line].zip(position).to_h.compact
    end

    def self.for_lookup(target, key, value)
      val = { 'value' => value }
      new(target, value: val, action: 'lookup', object: key)
    end

    def self.for_command(target, value, action, command, position)
      details = create_details(position)
      unless value['exit_code'] == 0
        details['exit_code'] = value['exit_code']
        value['_error'] = {
          'kind' => 'puppetlabs.tasks/command-error',
          'issue_code' => 'COMMAND_ERROR',
          'msg' => "The command failed with exit code #{value['exit_code']}",
          'details' => details
        }
      end
      new(target, value: value, action: action, object: command)
    end

    def self.for_task(target, stdout, stderr, exit_code, task, position)
      stdout.force_encoding('utf-8') unless stdout.encoding == Encoding::UTF_8

      details = create_details(position)
      value = if stdout.valid_encoding?
                parse_hash(stdout) || { '_output' => stdout }
              else
                { '_error' => { 'kind' => 'puppetlabs.tasks/task-error',
                                'issue_code' => 'TASK_ERROR',
                                'msg' => 'The task result contained invalid UTF-8 on stdout',
                                'details' => details } }
              end

      if exit_code != 0 && value['_error'].nil?
        msg = if stdout.empty?
                if stderr.empty?
                  "The task failed with exit code #{exit_code} and no output"
                else
                  "The task failed with exit code #{exit_code} and no stdout, but stderr contained:\n#{stderr}"
                end
              else
                "The task failed with exit code #{exit_code}"
              end
        details['exit_code'] = exit_code
        value['_error'] = { 'kind' => 'puppetlabs.tasks/task-error',
                            'issue_code' => 'TASK_ERROR',
                            'msg' => msg,
                            'details' => details }
      end

      if value.key?('_error')
        unless value['_error'].is_a?(Hash) && value['_error'].key?('msg')
          details['original_error'] = value['_error']
          value['_error'] = {
            'msg'     => "Invalid error returned from task #{task}: #{value['_error'].inspect}. Error "\
                         "must be an object with a msg key.",
            'kind'    => 'bolt/invalid-task-error',
            'details' => details
          }
        end

        value['_error']['kind']    ||= 'bolt/error'
        value['_error']['details'] ||= details
      end

      if value.key?('_sensitive')
        value['_sensitive'] = Puppet::Pops::Types::PSensitiveType::Sensitive.new(value['_sensitive'])
      end

      new(target, value: value, action: 'task', object: task)
    end

    def self.parse_hash(string)
      value = JSON.parse(string)
      value if value.is_a? Hash
    rescue JSON::ParserError
      nil
    end

    def self.for_upload(target, source, destination)
      new(target, message: "Uploaded '#{source}' to '#{target.host}:#{destination}'", action: 'upload', object: source)
    end

    def self.for_download(target, source, destination, download)
      msg   = "Downloaded '#{target.host}:#{source}' to '#{destination}'"
      value = { 'path' => download }

      new(target, value: value, message: msg, action: 'download', object: source)
    end

    # Satisfies the Puppet datatypes API
    def self.from_asserted_args(target, value)
      new(target, value: value)
    end

    def self._pcore_init_from_hash
      raise "Result shouldn't be instantiated from a pcore_init class method. How did this get called?"
    end

    def _pcore_init_from_hash(init_hash)
      opts = init_hash.reject { |k, _v| k == 'target' }
      initialize(init_hash['target'], opts.transform_keys(&:to_sym))
    end

    def _pcore_init_hash
      { 'target' => @target,
        'error' => @value['_error'],
        'message' => @value['_output'],
        'value' => @value,
        'action' => @action,
        'object' => @object }
    end

    def initialize(target, error: nil, message: nil, value: nil, action: 'action', object: nil)
      @target = target
      @value = value || {}
      @action = action
      @object = object
      if error && !error.is_a?(Hash)
        raise "TODO: how did we get a string error"
      end
      @value['_error'] = error if error
      @value['_output'] = message if message
    end

    def message
      @value['_output']
    end

    def message?
      message && !message.strip.empty?
    end

    def generic_value
      safe_value.reject { |k, _| %w[_error _output].include? k }
    end

    def eql?(other)
      self.class == other.class &&
        target == other.target &&
        value == other.value
    end
    alias == eql?

    def [](key)
      value[key]
    end

    def to_json(opts = nil)
      to_data.to_json(opts)
    end

    def to_s
      to_json
    end

    # This is the value with all non-UTF-8 characters removed, suitable for
    # printing or converting to JSON. It *should* only be possible to have
    # non-UTF-8 characters in stdout/stderr keys as they are not allowed from
    # tasks but we scrub the whole thing just in case.
    def safe_value
      Bolt::Util.walk_vals(value) do |val|
        if val.is_a?(String)
          # Replace invalid bytes with hex codes, ie. \xDE\xAD\xBE\xEF
          val.scrub { |c| c.bytes.map { |b| "\\x" + b.to_s(16).upcase }.join }
        else
          val
        end
      end
    end

    def to_data
      serialized_value = safe_value
      if serialized_value.key?('_sensitive') &&
         serialized_value['_sensitive'].is_a?(Puppet::Pops::Types::PSensitiveType::Sensitive)
        serialized_value['_sensitive'] = serialized_value['_sensitive'].to_s
      end
      {
        "target" => @target.name,
        "action" => action,
        "object" => object,
        "status" => status,
        "value" => serialized_value
      }
    end

    def status
      ok? ? 'success' : 'failure'
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

    def sensitive
      value['_sensitive']
    end
  end
end
