# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/pkcs7'
require 'bolt/util'

describe Bolt::Plugin::Pkcs7 do
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @boltdir = dir
      example.run
    end
  end

  let(:context) do
    context = instance_double("Bolt::Plugin::PluginContext")
    allow(context).to receive(:boltdir).and_return(@boltdir)
    context
  end

  let(:pkcs7) { Bolt::Plugin::Pkcs7.new(context: context, config: {}) }

  it 'createskeys' do
    pkcs7.secret_createkeys
    expect(File.exist?(File.join(@boltdir, 'keys', 'private_key.pkcs7.pem'))).to eq(true)
    expect(File.exist?(File.join(@boltdir, 'keys', 'public_key.pkcs7.pem'))).to eq(true)
    # File permissions work differently on windows and bolt cannot chmod the file.
    unless Bolt::Util.windows?
      expect(File.stat(File.join(@boltdir, 'keys', 'private_key.pkcs7.pem')).mode.to_s(8)[3..-1]).to eq('600')
    end
  end

  it 'has reversible encryption' do
    pkcs7.secret_createkeys
    value = "mystringval"
    enc = pkcs7.secret_encrypt('plaintext_value' => value)
    expect(enc).to start_with('ENC[PKCS7,')
    expect(pkcs7.secret_decrypt('encrypted_value' => enc)).to eq(value)
  end
end
