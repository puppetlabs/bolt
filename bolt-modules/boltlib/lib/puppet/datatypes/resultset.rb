# frozen_string_literal: true

Puppet::DataTypes.create_type('ResultSet') do
  interface <<-PUPPET
    attributes => {
      'results' => Array[Variant[Result, ApplyResult]],
    },
    functions => {
      count => Callable[[], Integer],
      empty => Callable[[], Boolean],
      error_set => Callable[[], ResultSet],
      filter_set => Callable[[Callable], ResultSet],
      find => Callable[[String[1]], Optional[Variant[Result, ApplyResult]]],
      first => Callable[[], Optional[Variant[Result, ApplyResult]]],
      names => Callable[[], Array[String[1]]],
      ok => Callable[[], Boolean],
      ok_set => Callable[[], ResultSet],
      targets => Callable[[], Array[Target]],
      to_data => Callable[[], Array[Hash]],
      '[]' => Variant[Callable[[Integer], Optional[Variant[Result, ApplyResult, Array[Variant[Result, ApplyResult]]]]],
                      Callable[[Integer, Integer], Optional[Variant[Result, ApplyResult, Array[Variant[Result, ApplyResult]]]]]
                     ]
    }
  PUPPET

  load_file('bolt/result_set')

  # Needed for Puppet to recognize Bolt::ResultSet as a Puppet object when deserializing
  Bolt::ResultSet.include(Puppet::Pops::Types::PuppetObject)
  implementation_class Bolt::ResultSet
end
