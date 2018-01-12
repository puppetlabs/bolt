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
  end

  class RunFailure < Error
    attr_reader :resultset

    def initialize(resultset, action, object)
      details = {
        action: action,
        object: object,
        failed_targets: resultset.error_set.names
      }
      message = "Plan aborted: #{action} '#{object}' failed on #{details[:failed_targets].length} nodes"
      super(message, 'bolt/run-failure', details)
      @resultset = resultset
      @error_code = 2
    end
  end
end
