# frozen_string_literal: true

require 'bolt/error'

# Collects facts based on a list of certnames.
#
# If a node is not found in PuppetDB, it's included in the returned hash with an empty facts hash.
# Otherwise, the node is included in the hash with a value that is a hash of its facts.
Puppet::Functions.create_function(:puppetdb_fact) do
  # Collect facts from PuppetDB.
  #
  # @param certnames Array of certnames.
  # @return A hash of certname to facts hash for each matched Target.
  # @example Get facts for nodes
  #   puppetdb_fact(['app.example.com', 'db.example.com'])
  dispatch :puppetdb_fact do
    param 'Array[String]', :certnames
    return_type 'Hash[String, Data]'
  end

  # Collects facts from a named PuppetDB instance.
  #
  # @param certnames Array of certnames.
  # @param instance The PuppetDB instance to query.
  # @return A hash of certname to facts hash for each matched Target.
  # @example Get facts for nodes from a named PuppetDB instance
  #   puppetdb_fact(['app.example.com', 'db.example.com'], 'instance-1')
  dispatch :puppetdb_fact_with_instance do
    param 'Array[String]', :certnames
    param 'String', :instance
    return_type 'Hash[String, Data]'
  end

  def puppetdb_fact(certnames)
    puppetdb_fact_with_instance(certnames, nil)
  end

  def puppetdb_fact_with_instance(certnames, instance)
    puppetdb_client = Puppet.lookup(:bolt_pdb_client)
    # Bolt executor not expected when invoked from apply block
    executor = Puppet.lookup(:bolt_executor) { nil }
    # Send Analytics Report
    executor&.report_function_call(self.class.name)

    puppetdb_client.facts_for_node(certnames, instance)
  end
end
