# frozen_string_literal: true

require 'spec_helper'
require 'bolt/puppetfile/installer'

describe Bolt::Puppetfile::Installer do
  context 'when BOLT_FORGE_TOKEN is not set' do
    before { ENV['BOLT_FORGE_TOKEN'] = nil }

    it 'raises an error' do
      expect { Bolt::Puppetfile::Installer.new }.to raise_error(Bolt::Error, /BOLT_FORGE_TOKEN is not set/)
    end
  end

  context 'when BOLT_FORGE_TOKEN is invalid' do
    before { ENV['BOLT_FORGE_TOKEN'] = 'invalid token' }

    it 'raises an error' do
      expect { Bolt::Puppetfile::Installer.new }.to raise_error(Bolt::Error, /BOLT_FORGE_TOKEN is invalid/)
    end
  end

  context 'when BOLT_FORGE_TOKEN is valid' do
    before { ENV['BOLT_FORGE_TOKEN'] = 'validtoken123' }

    it 'does not raise an error' do
      expect { Bolt::Puppetfile::Installer.new }.not_to raise_error
    end
  end
end
