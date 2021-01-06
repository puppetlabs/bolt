# frozen_string_literal: true

require 'bolt/plugin/puppet_connect_data'
require 'spec_helper'

describe Bolt::Plugin::PuppetConnectData do
  def mock_context(project_dir)
    context = double('Plugin::PluginContext')
    allow(context).to receive(:boltdir).and_return(project_dir)
    context
  end

  let(:subject) { described_class.new(context: mock_context('project_dir')) }

  it 'defines the correct plugin name' do
    expect(subject.name).to eq('puppet_connect_data')
  end

  it 'defines resolve_reference hooks' do
    expect(subject.hooks).to include(:resolve_reference, :validate_resolve_reference)
  end

  it 'fails if no key is specified' do
    reference = { '_plugin' => 'puppet_connect_data' }
    expect { subject.validate_resolve_reference(reference) }.to raise_error(
      Bolt::ValidationError, /requires.*key/
    )
  end

  context 'when <project_root>/puppet_connect_data.yaml does not exist' do
    it 'resolves all references to nil' do
      reference = { '_plugin' => 'puppet_connect_data', 'key' => 'foo_key' }
      expect(subject.resolve_reference(reference)).to be_nil
    end
  end

  context 'when <project_root>/puppet_connect_data.yaml exists' do
    def with_project(name, puppet_connect_data)
      Dir.mktmpdir('puppet_connect_data_plugin_test_project', Dir.pwd) do |tmpdir|
        File.write(File.join(tmpdir, 'bolt-project.yaml'), { 'name' => name })
        File.write(File.join(tmpdir, 'puppet_connect_data.yaml'), puppet_connect_data)
        yield tmpdir
      end
    end

    context 'when it is not a valid YAML file' do
      it 'raises an error during initialization' do
        with_project('bad_yaml_file', 'not_yaml') do |project_dir|
          context = mock_context(project_dir)
          expect { described_class.new(context: context) }.to raise_error(/yaml/)
        end
      end
    end

    context 'when it is a valid YAML file' do
      let(:data) do
        {
          'foo_key'    => 'foo_value',
          'plugin_key' => {
            '_plugin' => 'prompt',
            'message' => 'foo_message'
          }
        }
      end

      it "returns the key's value" do
        with_project('specified_key', data.to_yaml) do |project_dir|
          context = mock_context(project_dir)
          subj = described_class.new(context: context)
          reference = { '_plugin' => 'puppet_connect_data', 'key' => 'foo_key' }
          expect(subj.resolve_reference(reference)).to eql('foo_value')
        end
      end

      it "returns nil for missing keys" do
        with_project('missing_key', data.to_yaml) do |project_dir|
          context = mock_context(project_dir)
          subj = described_class.new(context: context)
          reference = { '_plugin' => 'puppet_connect_data', 'key' => 'missing_key' }
          expect(subj.resolve_reference(reference)).to be_nil
        end
      end
    end
  end
end
