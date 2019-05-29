# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/terraform'

# rubocop:disable Style/BracesAroundHashParameters
describe Bolt::Plugin::Terraform do
  let(:terraform_dir) { File.expand_path(File.join(__dir__, '../../fixtures/terraform')) }
  let(:resource_type) { 'google_compute_instance.*' }
  let(:uri) { 'network_interface.0.access_config.0.nat_ip' }

  it 'has a hook for lookup_targets' do
    expect(subject.hooks).to eq(['lookup_targets'])
  end

  it 'reads the terraform state file from the given directory' do
    statefile = File.join(terraform_dir, 'terraform.tfstate')
    state = subject.load_statefile('dir' => terraform_dir)

    expect(state).to eq(JSON.parse(File.read(statefile)))
  end

  it 'accepts another name for the state file' do
    statefile = File.join(terraform_dir, 'empty.tfstate')
    state = subject.load_statefile('dir' => terraform_dir, 'statefile' => 'empty.tfstate')

    expect(state).to eq(JSON.parse(File.read(statefile)))
  end

  shared_examples('loading terraform targets') do
    let(:opts) do
      { 'dir' => terraform_dir,
        'statefile' => statefile,
        'resource_type' => resource_type,
        'uri' => uri }
    end

    it 'matches resources that start with the given type' do
      targets = subject.lookup_targets(opts)

      expect(targets).to contain_exactly({ 'uri' => ip0 }, { 'uri' => ip1 })
    end

    it 'can filter resources by regex' do
      targets = subject.lookup_targets(opts.merge('resource_type' => 'google_compute_instance.example.\d+'))

      expect(targets).to contain_exactly({ 'uri' => ip0 }, { 'uri' => ip1 })
    end

    it 'maps inventory to name' do
      targets = subject.lookup_targets(opts.merge('name' => 'id'))

      expect(targets).to contain_exactly({ 'uri' => ip0, 'name' => 'test-instance-0' },
                                         { 'uri' => ip1, 'name' => 'test-instance-1' })
    end

    it 'builds a config map from the inventory' do
      config_template = { 'ssh' => { 'user' => 'metadata.sshUser' } }
      targets = subject.lookup_targets(opts.merge('config' => config_template))

      config = { 'ssh' => { 'user' => 'someone' } }
      expect(targets).to contain_exactly({ 'uri' => ip0, 'config' => config },
                                         { 'uri' => ip1, 'config' => config })
    end

    it 'returns nothing if there are no matching resources' do
      targets = subject.lookup_targets(opts.merge('resource_type' => 'aws_instance'))

      expect(targets).to be_empty
    end

    it 'fails if the state file does not exist' do
      expect { subject.lookup_targets(opts.merge('statefile' => 'nonexistent.tfstate')) }
        .to raise_error(Bolt::Error, /Could not load Terraform state file nonexistent.tfstate/)
    end
  end

  describe "using a terrform version 3 state file" do
    let(:statefile) { 'terraform3.tfstate' }
    let(:ip0) { '34.83.150.52' }
    let(:ip1) { '34.83.16.240' }

    include_examples 'loading terraform targets'
  end

  describe "using a terraform version 4 state file" do
    let(:statefile) { 'terraform.tfstate' }
    let(:ip0) { '34.83.160.116' }
    let(:ip1) { '35.230.3.44' }

    include_examples 'loading terraform targets'
  end
end
# rubocop:enable Style/BracesAroundHashParameters
