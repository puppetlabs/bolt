# frozen_string_literal: true

require 'spec_helper'

require 'bolt/module_installer/specs/id/github'

describe Bolt::ModuleInstaller::Specs::ID::GitHub do
  let(:id)       { described_class.request(git, ref, nil) }
  let(:git)      { "https://github.com/puppetlabs/#{name}" }
  let(:ref)      { '0.1.0' }
  let(:sha)      { 'bdaa6b531fde16baab5752916a49423925493f2f' }
  let(:name)     { 'puppetlabs-yaml' }
  let(:metadata) { "{\"name\":\"#{name}\"}" }
  let(:sha_json) { "{\"sha\":\"#{sha}\"}" }

  let(:metadata_response) { double('metadata_response', body: metadata) }
  let(:sha_response)      { double('sha_response', body: sha_json) }

  before(:each) do
    allow(described_class).to receive(:make_request)
      .with(/raw.githubusercontent.com/, any_args)
      .and_return(metadata_response)
    allow(described_class).to receive(:make_request)
      .with(/api.github.com/, any_args)
      .and_return(sha_response)
    allow(Net::HTTPOK).to receive(:===).with(metadata_response).and_return(true)
    allow(Net::HTTPOK).to receive(:===).with(sha_response).and_return(true)
  end

  it 'returns module name and sha' do
    expect(id).to be_instance_of(described_class)
    expect(id.name).to eq(name)
    expect(id.sha).to eq(sha)
  end

  it 'returns nil if not a GitHub repo' do
    id = described_class.request('https://gitlab.com/puppetlabs/puppetlabs-yaml', ref, nil)
    expect(id).to eq(nil)
  end

  it 'returns nil if unable to find metadata file' do
    allow(Net::HTTPOK).to receive(:===).with(metadata_response).and_return(false)
    expect(id).to eq(nil)
    expect(@log_output.readlines).to include(/Unable to find metadata file/)
  end

  it 'errors if unable to parse metadata' do
    allow(metadata_response).to receive(:body).and_return('foo')
    expect { id }.to raise_error(/Unable to parse metadata as JSON/)
  end

  it 'errors if metadata is not a Hash' do
    allow(metadata_response).to receive(:body).and_return('"foo"')
    expect { id }.to raise_error(/Invalid metadata. Expected a Hash, got a String/)
  end

  it 'errors if metadata is missing a name' do
    allow(metadata_response).to receive(:body).and_return('{}')
    expect { id }.to raise_error(/Invalid metadata. Metadata must include a 'name' key./)
  end

  it 'errors if unable to calculate SHA' do
    expect(Net::HTTPOK).to receive(:===).with(sha_response).and_return(false)
    expect(id).to eq(nil)
    expect(@log_output.readlines).to include(/Unable to calculate SHA for ref #{ref}/)
  end
end
