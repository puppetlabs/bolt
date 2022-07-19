# frozen_string_literal: true

# An [apply action](applying_manifest_blocks.md#return-value-of-apply-action)
# returns an `ApplyResult`. An `ApplyResult` is part of a `ResultSet` object and
# contains information about the apply action.
#
# @param report
#   The Puppet report from the apply action. Equivalent to calling `ApplyResult.value['report']`.
#   The report is a hash representation of the [`Puppet::Transaction::Report`
#   object](https://puppet.com/docs/puppet/latest/format_report.html), where each property
#   corresponds to a key in the report hash. For more information, see [Result
#   keys](applying_manifest_blocks.md#result-keys).
# @param target
#   The target the result is from.
# @param error
#   An Error object constructed from the `_error` field of the result's value.
# @param catalog
#   The Puppet catalog used to configure the target. The catalog describes the
#   desired state of the target. The catalog is masked with the `Sensitive` data
#   type to protect any sensitive information in the catalog from being printed
#   to the console or logs. Using this function automatically unwraps the
#   catalog. For more information about catalogs and the catalog compilation
#   process, see [Catalog
#   compilation](https://puppet.com/docs/puppet/latest/subsystem_catalog_compilation.html).

#
# @!method action
#   The action performed. `ApplyResult.action` always returns the string `apply`.
# @!method message
#   The `_output` field of the result's value.
# @!method ok
#   Whether the result was successful.
# @!method to_data
#   A serialized representation of `ApplyResult`.
# @!method value
#   A hash including the Puppet report from the apply action under a `report` key.
#
Puppet::DataTypes.create_type('ApplyResult') do
  interface <<-PUPPET
    attributes => {
      'report' => Hash[String[1], Data],
      'target' => Target,
      'error' => Optional[Error],
      'catalog' => Optional[Hash]
    },
    functions => {
      ok => Callable[[], Boolean],
      message => Callable[[], Optional[String]],
      action => Callable[[], String],
      to_data => Callable[[], Hash],
      value => Callable[[], Hash]
    }
  PUPPET

  load_file('bolt/apply_result')

  # Needed for Puppet to recognize Bolt::ApplyResult as a Puppet object when deserializing
  Bolt::ApplyResult.include(Puppet::Pops::Types::PuppetObject)
  implementation_class Bolt::ApplyResult
end
