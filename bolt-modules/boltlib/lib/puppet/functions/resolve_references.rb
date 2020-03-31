# frozen_string_literal: true

require 'bolt/error'
require 'bolt/pal/issues'

# Evaluates all `_plugin` references in a hash and returns the resolved reference data.
Puppet::Functions.create_function(:resolve_references) do
  # Resolve references.
  # @param references A hash of reference data to resolve.
  # @return A hash of resolved reference data.
  # @example Resolve a hash of reference data
  #   $references = {
  #     "targets" => [
  #       "_plugin" => "terraform",
  #       "dir" => "path/to/terraform/project",
  #       "resource_type" => "aws_instance.web",
  #       "uri" => "public_ip"
  #     ]
  #   }
  #
  #   resolve_references($references)
  dispatch :resolve_references do
    param 'Data', :references
    return_type 'Data'
  end

  def resolve_references(references)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(
          Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
          action: 'resolve_references'
        )
    end

    executor = Puppet.lookup(:bolt_executor)
    executor.report_function_call(self.class.name)

    plugins = Puppet.lookup(:bolt_inventory).plugins
    plugins.resolve_references(references)
  end
end
