# frozen_string_literal: true

require 'spec_helper'
require 'bolt/applicator'
require 'bolt/target'

describe Bolt::Applicator do
  let(:inventory) { nil }
  let(:applicator) { Bolt::Applicator.new(inventory, nil, :mod, :pdb) }

  it 'instantiates' do
    expect(applicator).to be
  end

  context 'with inventory' do
    let(:inventory) { double(:inventory, facts: {}, vars: {}) }

    it 'passes catalog input' do
      target = Bolt::Target.new('pcp://foobar')
      input = {
        code_ast: :ast,
        modulepath: :mod,
        pdb_config: :pdb,
        target: {
          name: 'foobar',
          facts: {},
          variables: {},
          trusted: {
            authenticated: 'local',
            certname: 'foobar',
            extensions: {},
            hostname: 'foobar',
            domain: nil
          }
        }
      }
      expect(Open3).to receive(:capture3)
        .with('ruby', /bolt_catalog/, 'compile', stdin_data: input.to_json)
        .and_return(['{}', :err, double(:status, success?: true)])
      expect(applicator.compile(target, :ast, {})).to eq({})
    end
  end
end
