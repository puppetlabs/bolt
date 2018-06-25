# frozen_string_literal: true

require 'open3'

module Bolt
  class Applicator
    def initialize(inventory)
      @inventory = inventory
    end

    def apply(args, apply_body, _scope)
      raise(ArgumentError, 'apply requires a TargetSpec') if args.empty?
      type = Puppet.lookup(:pal_script_compiler).type('TargetSpec')
      Puppet::Pal.assert_type(type, args[0], 'apply targets')

      targets = @inventory.get_targets(args[0])
      ast = Puppet::Pops::Serialization::ToDataConverter.convert(apply_body, rich_data: true, symbol_to_string: true)
      targets.each do |target|
        catalog_input = {
          code_ast: ast,
          modulepath: [],
          target: {
            name: target.host,
            facts: @inventory.facts(target),
            variables: @inventory.vars(target)
          }
        }
        o, _s = Open3.capture2('bolt_catalog', 'compile', stdin_data: catalog_input.to_json)
        puts o
      end
    end
  end
end
