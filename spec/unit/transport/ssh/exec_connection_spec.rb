# frozen_string_literal: true

require 'spec_helper'
require 'net/ssh'
require 'bolt/inventory'
require 'bolt/transport/ssh/exec_connection'
require 'bolt_spec/files'

describe Bolt::Transport::SSH::ExecConnection do
  include BoltSpec::Files

  let(:uri) { 'ssh://foo.example.com' }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target(uri) }
  let(:subject) { described_class.new(target) }

  before :each do
    allow(Net::SSH::Config).to receive(:for).and_return(user: 'sshuser')
    inventory.set_config(target, 'ssh', 'native-ssh' => true)
  end

  context 'when copying files' do
    it 'uses configured copy-command' do
      inventory.set_config(target, %w[ssh copy-command], ['scp', '-o', 'Port=21'])

      expect(Open3).to receive(:capture3)
        .with("scp", "-o", "Port=21", "-o", "BatchMode=yes", "good", "sshuser@foo.example.com:afternoon")
        .and_return(['{}', '', double(:status, success?: true)])
      subject.upload_file('good', 'afternoon')
    end

    it 'rejects invalid copy-command' do
      inventory.set_config(target, %w[ssh copy-command], 3)

      expect { subject.upload_file('good', 'evening') }.to raise_error(Bolt::ValidationError)
    end

    it 'builds scp command with port' do
      inventory.set_config(target, %w[ssh port], 24)

      expect(Open3).to receive(:capture3)
        .with("scp", "-r", "-o", "BatchMode=yes", "-o", "Port=24", "good", "sshuser@foo.example.com:night")
        .and_return(['{}', '', double(:status, success?: true)])
      subject.upload_file('good', 'night')
    end

    it 'omits BatchMode when disabled' do
      # Requires ssh-command is set to change batch-mode
      inventory.set_config(target, %w[ssh ssh-command], 'ssh')
      inventory.set_config(target, %w[ssh batch-mode], false)

      expect(Open3).to receive(:capture3)
        .with("scp", "-r", "good", "sshuser@foo.example.com:night")
        .and_return(['{}', '', double(:status, success?: true)])
      subject.upload_file('good', 'night')
    end
  end

  context 'when executing' do
    it 'builds ssh command' do
      inventory.set_config(target, %w[ssh ssh-command], ['good', '-morning'])

      expect(Open3).to receive(:popen3)
        .with("good", "-morning", "-o", "BatchMode=yes", "sshuser@foo.example.com", "--", "is it Friday?")
      subject.execute('is it Friday?')
    end

    it 'builds ssh command with port' do
      inventory.set_config(target, %w[ssh port], 23)

      expect(Open3).to receive(:popen3)
        .with("ssh", "-o", "BatchMode=yes", "-o", "Port=23", "sshuser@foo.example.com", "--", "I don't know")
      subject.execute("I don't know")
    end

    it 'builds ssh command with key' do
      keypath = fixtures_path('keys', 'id_rsa')
      inventory.set_config(target, %w[ssh private-key], keypath)

      expect(Open3).to receive(:popen3)
        .with("ssh", "-o", "BatchMode=yes", "-i", keypath, "sshuser@foo.example.com", "--", "what is time?")
      subject.execute('what is time?')
    end

    it 'builds ssh command without batch-mode when false' do
      # Currently requires ssh-command is set to change batch-mode
      inventory.set_config(target, %w[ssh ssh-command], 'ssh')
      inventory.set_config(target, %w[ssh batch-mode], false)

      expect(Open3).to receive(:popen3)
        .with("ssh", "sshuser@foo.example.com", "--", "what is time?")
      subject.execute('what is time?')
    end

    it 'fails if key is not a string' do
      inventory.set_config(target, %w[ssh private-key], 'key-data' => 'beepboop')

      expect { subject.execute('ls') }
        .to raise_error(/private-key must be a filepath when using native-ssh/)
    end

    it 'errors with invalid ssh-command' do
      inventory.set_config(target, %w[ssh ssh-command], 3)

      expect { subject.execute('ls') }.to raise_error(Bolt::ValidationError)
    end
  end
end
