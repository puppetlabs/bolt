# frozen_string_literal: true

module Bolt
  class Error < RuntimeError
    attr_reader :kind, :details, :issue_code, :error_code

    def initialize(msg, kind, details = nil, issue_code = nil)
      super(msg)
      @kind = kind
      @issue_code = issue_code
      @details = details || {}
      @error_code ||= 1
    end

    def msg
      message
    end

    def to_h
      h = { 'kind' =>  kind,
            'msg' => message,
            'details' => details }
      h['issue_code'] = issue_code if issue_code
      h
    end

    def to_json(opts = nil)
      to_h.to_json(opts)
    end

    def to_puppet_error
      Puppet::DataTypes::Error.from_asserted_hash(to_h)
    end

    def self.unknown_task(task)
      "Could not find a task named \"#{task}\". For a list of available tasks, run \"bolt task show\""
    end

    def self.unknown_plan(plan)
      "Could not find a plan named \"#{plan}\". For a list of available plans, run \"bolt plan show\""
    end
  end

  class RunFailure < Error
    attr_reader :result_set

    def initialize(result_set, action, object)
      details = {
        'action' => action,
        'object' =>  object,
        'result_set' => result_set
      }
      message = "Plan aborted: #{action} '#{object}' failed on #{result_set.error_set.length} nodes"
      super(message, 'bolt/run-failure', details)
      @result_set = result_set
      @error_code = 2
    end
  end

  class PlanFailure < Error
    def initialize(*args)
      super(*args)
      @error_code = 2
    end
  end

  class PuppetError < Error
    def self.convert_puppet_errors(result)
      Bolt::Util.walk_vals(result) { |v| v.is_a?(Puppet::DataTypes::Error) ? from_error(v) : v }
    end

    def self.from_error(err)
      new(err.msg, err.kind, err.details, err.issue_code)
    end
  end
end
