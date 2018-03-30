# frozen_string_literal: true

require 'bolt/error'

# Returns a hash of certname to facts objects for each matched Target.  This
# functions accepts an array of certnames and returns a hash of target
# certnames and their corresponding facts hash.
#
# * If a node is not found in PuppetDB, it's included in the returned hash with empty facts hash.
# * Otherwise the node is included in the hash with a value that is a hash of it's facts.
#
Puppet::Functions.create_function(:puppetdb_fact) do
  dispatch :puppetdb_fact do
    param 'Array[String]', :targets
    return_type 'Hash[String, Data]'
  end

  def puppetdb_fact(targets)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, operation: 'puppetdb_fact'
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    executor.puppetdb_fact(targets)
  end
end
