# frozen_string_literal: true

require 'bolt/error'

# Makes a query to {https://puppet.com/docs/puppetdb/latest/index.html puppetdb}
# using Bolt's PuppetDB client.
Puppet::Functions.create_function(:puppetdb_query) do
  # rubocop:disable Metrics/LineLength
  # @param query A PQL query.
  #   {https://puppet.com/docs/puppetdb/latest/api/query/tutorial-pql.html Learn more about Puppet's query language, PQL}
  # @return Results of the PuppetDB query.
  # @example Request certnames for all nodes
  #   puppetdb_query('nodes[certname] {}')
  # rubocop:enable Metrics/LineLength
  dispatch :make_query do
    param 'Variant[String, Array[Data]]', :query
    return_type 'Array[Data]'
  end
  # The query type could be more specific ASTQuery = Array[Variant[String, ASTQuery]]

  def make_query(query)
    puppetdb_client = Puppet.lookup(:bolt_pdb_client) { nil }
    unless puppetdb_client
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('query facts from puppetdb')
      )
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    executor&.report_function_call('puppetdb_query')

    puppetdb_client.make_query(query)
  end
end
