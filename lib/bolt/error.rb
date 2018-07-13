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

  class CLIError < Bolt::Error
    def initialize(msg)
      super(msg, "bolt/cli-error")
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

  # This class is used to treat a Puppet Error datatype as a ruby error outside PAL
  class PuppetError < Error
    def self.from_error(err)
      new(err.msg, err.kind, err.details, err.issue_code)
    end
  end

  class ApplyError < Error
    def initialize(target, err)
      super("Apply failed to compile for #{target}: #{err}", 'bolt/apply-error')
    end
  end

  class ParseError < Error
    def initialize(msg)
      super(msg, 'bolt/parse-error')
    end
  end

  class InvalidPlanResult < Error
    def initialize(plan_name, result_str)
      super("Plan #{plan_name} returned an invalid result: #{result_str}",
            'bolt/invalid-plan-result',
            { 'plan_name' => plan_name,
              'result_string' => result_str })
    end
  end

  class ValidationError < Bolt::Error
    def initialize(msg)
      super(msg, 'bolt/validation-error')
    end
  end

  class FileError < Bolt::Error
    def initialize(msg, path)
      super(msg, 'bolt/file-error', { "path" => path })
    end
  end
end
