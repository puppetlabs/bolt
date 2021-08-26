# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt/module'

describe Bolt::Module do
  include BoltSpec::Files

  let(:modulepath) { [fixtures_path('modules')] }
  let(:project)    { double('project', load_as_module?: false) }
  let(:mods)       { Bolt::Module.discover(modulepath, project) }

  it 'returns the path' do
    expect(mods['vars'].name).to eq('vars')
    expect(mods['vars'].path).to eq(fixtures_path(%w[modules vars]))
    expect(mods['vars'].plugin?).to eq(false)
  end
end
