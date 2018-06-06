# frozen_string_literal: true

require 'bolt/error'

#
# Makes a query to puppetdb using the bolts puppetdb client.
#
Puppet::Functions.create_function(:puppetdb_query) do
  # This type could be more specific ASTQuery = Array[Variant[String, ASTQuery]]
  dispatch :make_query do
    param 'Variant[String, Array[Data]]', :query
    return_type 'Array[Data]'
  end

  def make_query(query)
    puppetdb_client = Puppet.lookup(:bolt_pdb_client) { nil }
    unless Puppet[:tasks] && puppetdb_client && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_MISSING_BOLT, action: _('query facts from puppetdb')
      )
    end

    puppetdb_client.make_query(query)
  end
end
