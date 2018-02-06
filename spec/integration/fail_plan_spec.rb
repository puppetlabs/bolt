require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/config'
require 'bolt_spec/integration'
require 'bolt/cli'

describe "When a plan fails" do
  include BoltSpec::Integration
  include BoltSpec::Config

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:modulepath) { fixture_path('modules') }
  let(:config_flags) {
    ['--format', 'json',
     '--configfile', fixture_path('configs', 'empty.yml'),
     '--modulepath', modulepath]
  }

  it 'returns the error object' do
    result = run_cli_json(['plan', 'run', 'error::args'] + config_flags, rescue_exec: true)
    if error_support
      expect(result).to eq('msg' => 'oops',
                           'kind' => 'test/oops',
                           'details' => { 'some' => 'info' })
    else
      expect(result['msg']).to match(/oops/)
      expect(result['kind']).to eq('bolt/cli-error')
    end
  end

  it 'returns the error object' do
    result = run_cli_json(['plan', 'run', 'error::err'] + config_flags, rescue_exec: true)
    if error_support
      expect(result).to eq('msg' => 'oops',
                           'kind' => 'test/oops',
                           'details' => { 'some' => 'info' })
    else
      expect(result['msg']).to match(/oops/)
      expect(result['kind']).to eq('bolt/cli-error')
    end
  end
end
