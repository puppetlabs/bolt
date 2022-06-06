# frozen_string_literal: true

require 'bolt/error'

# Makes a query to [puppetdb](https://puppet.com/docs/puppetdb/latest/index.html)
# using Bolt's PuppetDB client.
Puppet::Functions.create_function(:puppetdb_query) do
  # rubocop:disable Layout/LineLength
  # Make a query to PuppetDB.
  #
  # @param query A PQL query.
  #   Learn more about [Puppet's query language](https://puppet.com/docs/puppetdb/latest/api/query/tutorial-pql.html), PQL.
  # @return Results of the PuppetDB query.
  # @example Request certnames for all nodes
  #   puppetdb_query('nodes[certname] {}')
  # rubocop:enable Layout/LineLength
  dispatch :make_query do
    param 'Variant[String, Array[Data]]', :query
    return_type 'Array[Data]'
  end

  # rubocop:disable Layout/LineLength
  # Make a query to a named PuppetDB instance.
  #
  # @param query A PQL query.
  #   Learn more about [Puppet's query language](https://puppet.com/docs/puppetdb/latest/api/query/tutorial-pql.html), PQL.
  # @param instance The PuppetDB instance to query.
  # @return Results of the PuppetDB query.
  # @example Request certnames for all nodes using a named PuppetDB instance
  #   puppetdb_query('nodes[certname] {}', 'instance-1')
  # rubocop:enable Layout/LineLength
  dispatch :make_query_with_instance do
    param 'Variant[String, Array[Data]]', :query
    param 'String', :instance
    return_type 'Array[Data]'
  end
  # The query type could be more specific ASTQuery = Array[Variant[String, ASTQuery]]

  def make_query(query)
    make_query_with_instance(query, nil)
  end

  def make_query_with_instance(query, instance)
    puppetdb_client = Puppet.lookup(:bolt_pdb_client)
    # Bolt executor not expected when invoked from apply block
    executor = Puppet.lookup(:bolt_executor) { nil }
    # Send Analytics Report
    executor&.report_function_call(self.class.name)

    puppetdb_client.make_query(query, nil, instance)
  end
end
