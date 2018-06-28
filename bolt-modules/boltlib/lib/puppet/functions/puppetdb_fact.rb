# frozen_string_literal: true

require 'bolt/error'

# Collects facts based on a list of certnames.
#
# * If a node is not found in PuppetDB, it's included in the returned hash with empty facts hash.
# * Otherwise the node is included in the hash with a value that is a hash of it's facts.
Puppet::Functions.create_function(:puppetdb_fact) do
  # @param certnames Array of certnames.
  # @return A hash of certname to facts hash for each matched Target.
  # @example Get facts for nodes
  #   puppetdb_fact(['app.example.com', 'db.example.com'])
  dispatch :puppetdb_fact do
    param 'Array[String]', :certnames
    return_type 'Hash[String, Data]'
  end

  def puppetdb_fact(certnames)
    puppetdb_client = Puppet.lookup(:bolt_pdb_client) { nil }
    unless puppetdb_client
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('query facts from puppetdb')
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call('puppetdb_fact')

    puppetdb_client.facts_for_node(certnames)
  end
end
