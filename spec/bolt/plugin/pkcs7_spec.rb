# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/pkcs7'
require 'bolt/util'

describe Bolt::Plugin::Pkcs7 do
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @project = dir
      example.run
    end
  end

  let(:context) do
    context = instance_double("Bolt::Plugin::PluginContext")
    allow(context).to receive(:boltdir).and_return(@project)
    context
  end

  let(:pkcs7) { Bolt::Plugin::Pkcs7.new(context: context, config: {}) }

  it 'createskeys' do
    pkcs7.secret_createkeys
    expect(File.exist?(File.join(@project, 'keys', 'private_key.pkcs7.pem'))).to eq(true)
    expect(File.exist?(File.join(@project, 'keys', 'public_key.pkcs7.pem'))).to eq(true)
    # File permissions work differently on windows and bolt cannot chmod the file.
    unless Bolt::Util.windows?
      expect(File.stat(File.join(@project, 'keys', 'private_key.pkcs7.pem')).mode.to_s(8)[3..-1]).to eq('600')
    end
  end

  it 'has reversible encryption' do
    pkcs7.secret_createkeys
    value = "mystringval"
    enc = pkcs7.secret_encrypt('plaintext_value' => value)
    expect(enc).to start_with('ENC[PKCS7,')
    expect(pkcs7.secret_decrypt('encrypted_value' => enc)).to eq(value)
  end

  context 'using home directory in for key paths' do
    let(:pkcs7) do
      Bolt::Plugin::Pkcs7.new(context: context,
                              config: {
                                'private-key' => '~/.keys/private_key.pkcs7.pem',
                                'public-key' => '~/.keys/public_key.pkcs7.pem'
                              })
    end

    it 'resolves file paths' do
      home_dir = File.expand_path('~')
      expect(pkcs7.private_key_path).to eq("#{home_dir}/.keys/private_key.pkcs7.pem")
      expect(pkcs7.public_key_path).to eq("#{home_dir}/.keys/public_key.pkcs7.pem")
    end
  end
end
