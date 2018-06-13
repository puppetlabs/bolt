# frozen_string_literal: true

require 'bolt/error'

# Makes a query to puppetdb using Bolt's PuppetDB client.
Puppet::Functions.create_function(:puppetdb_query) do
  # @param query A PQL query.
  # @return Results of the PuppetDB query.
  # @example Request certnames for all nodes
  #   puppetdb_query('nodes[certname] {}')
  dispatch :make_query do
    param 'Variant[String, Array[Data]]', :query
    return_type 'Array[Data]'
  end
  # The query type could be more specific ASTQuery = Array[Variant[String, ASTQuery]]

  def make_query(query)
    puppetdb_client = Puppet.lookup(:bolt_pdb_client) { nil }
    unless Puppet[:tasks] && puppetdb_client && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('query facts from puppetdb')
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call('puppetdb_query')

    puppetdb_client.make_query(query)
  end
end
