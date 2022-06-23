# frozen_string_literal: true

require 'spec_helper'

require 'bolt/module_installer/specs/id/gitclone'

describe Bolt::ModuleInstaller::Specs::ID::GitClone do
  let(:id)       { described_class.request(git, ref, nil) }
  let(:git)      { "https://github.com/puppetlabs/#{name}" }
  let(:ref)      { '0.1.0' }
  let(:sha)      { 'bdaa6b531fde16baab5752916a49423925493f2f' }
  let(:name)     { 'puppetlabs-yaml' }
  let(:metadata) { "{\"name\":\"#{name}\"}" }

  let(:err)        { 'something went wrong' }
  let(:status)     { double('status', success?: true) }
  let(:err_status) { double('err_status', success?: false) }

  before(:each) do
    allow(described_class).to receive(:git?).and_return(true)
    allow(Open3).to receive(:capture3).with('git', 'rev-parse', any_args).and_return([sha, '', status])
    allow(Open3).to receive(:capture3).with('git', 'show', any_args).and_return([metadata, '', status])
    allow(Open3).to receive(:capture3).with('git', 'clone', any_args).and_return(['', '', status])
  end

  it 'returns module name and SHA' do
    expect(id).to be_instance_of(described_class)
    expect(id.name).to eq(name)
    expect(id.sha).to eq(sha)
  end

  it 'returns nil if git executable is not available' do
    allow(described_class).to receive(:git?).and_return(false)
    expect(id).to eq(nil)
    expect(@log_output.readlines).to include(/'git' executable not found/)
  end

  it 'returns nil if unable to clone repo' do
    allow(Open3).to receive(:capture3).and_return(['', err, err_status])
    expect(id).to eq(nil)
    expect(@log_output.readlines).to include(/Unable to clone bare repo.*#{err}/, /Unable to clone repo.*#{err}/)
  end

  it 'errors if unable to find metadata' do
    expect(Open3).to receive(:capture3).with('git', 'show', any_args).and_return(['', err, err_status])
    expect { id }.to raise_error(/Unable to find metadata file.*#{err}/)
  end

  it 'errors if unable to parse metadata' do
    expect(Open3).to receive(:capture3).with('git', 'show', any_args).and_return(['foo', '', status])
    expect { id }.to raise_error(/Unable to parse metadata as JSON/)
  end

  it 'errors if metadata is not a Hash' do
    expect(Open3).to receive(:capture3).with('git', 'show', any_args).and_return(['"foo"', '', status])
    expect { id }.to raise_error(/Invalid metadata. Expected a Hash, got a String/)
  end

  it 'errors if metadata is missing a name' do
    expect(Open3).to receive(:capture3).with('git', 'show', any_args).and_return(['{}', '', status])
    expect { id }.to raise_error(/Invalid metadata. Metadata must include a 'name' key./)
  end

  it 'errors if unable to calculate SHA' do
    expect(Open3).to receive(:capture3).with('git', 'rev-parse', any_args).and_return(['', err, err_status])
    expect { id }.to raise_error(/Unable to calculate SHA for ref #{ref}.*#{err}/)
  end
end
