# frozen_string_literal: true

require 'spec_helper'
require 'net/ssh'
require 'bolt/inventory'
require 'bolt/transport/ssh/connection'
require 'bolt_spec/errors'

describe Bolt::Transport::SSH::Connection do
  include BoltSpec::Errors

  let(:uri) { 'ssh://foo.example.com' }
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target(uri) }
  let(:transport_logger) { Logging.logger[Net::SSH] }
  let(:subject) { described_class.new(target, transport_logger) }

  context "when setting user" do
    before :each do
      allow(Net::SSH::Config).to receive(:for).and_return(user: 'sshuser')
      allow(Etc).to receive(:getlogin).and_return('loginuser')
    end

    it "uses the target's user if one is set" do
      inventory.set_config(target, 'ssh', 'user' => 'targetuser')
      expect(subject.user).to eq('targetuser')
    end

    it "uses the SSH config user if no target user is set" do
      expect(subject.user).to eq('sshuser')
    end

    it "falls back to the login user if no SSH config or target user is set" do
      allow(Net::SSH::Config).to receive(:for).and_return({})
      expect(subject.user).to eq('loginuser')
    end

    it "doesn't check SSH config if load-config is false" do
      inventory.set_config(target, 'ssh', 'load-config' => false)
      expect(subject.user).to eq('loginuser')
    end
  end

  context "when connecting", ssh: true do
    before :each do
      # We can't allow(subject) here because we rely on subject being lazily
      # instantiated so we can tweak the config per-test first.
      allow_any_instance_of(described_class).to receive(:validate_ssh_version)
    end

    it "passes filtered encryption algorithms" do
      inventory.set_config(target, 'ssh', 'encryption-algorithms' => %w[aes256-ctr fake])

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:encryption]).to match_array(['aes256-ctr'])
      end

      subject.connect
    end

    it "expands default encryption algorithms" do
      inventory.set_config(target, 'ssh', 'encryption-algorithms' => ['defaults'])

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:encryption]).to match_array(Net::SSH::Transport::Algorithms::DEFAULT_ALGORITHMS[:encryption])
      end

      subject.connect
    end

    it "passes filtered host_key algorithms" do
      inventory.set_config(target, 'ssh', 'host-key-algorithms' => %w[ssh-rsa fake])

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:host_key]).to match_array(['ssh-rsa'])
      end

      subject.connect
    end

    it "expands default host_key algorithms" do
      inventory.set_config(target, 'ssh', 'host-key-algorithms' => ['defaults'])

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:host_key]).to match_array(Net::SSH::Transport::Algorithms::DEFAULT_ALGORITHMS[:host_key])
      end

      subject.connect
    end

    it "passes filtered kex algorithms" do
      inventory.set_config(target, 'ssh', 'kex-algorithms' => %w[diffie-hellman-group14-sha1 fake])

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:kex]).to match_array(['diffie-hellman-group14-sha1'])
      end

      subject.connect
    end

    it "expands default kex algorithms" do
      inventory.set_config(target, 'ssh', 'kex-algorithms' => ['defaults'])

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:kex]).to match_array(Net::SSH::Transport::Algorithms::DEFAULT_ALGORITHMS[:kex])
      end

      subject.connect
    end

    it "passes filtered mac algorithms" do
      inventory.set_config(target, 'ssh', 'mac-algorithms' => %w[hmac-sha1 fake])

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:hmac]).to match_array(['hmac-sha1'])
      end

      subject.connect
    end

    it "expands default mac algorithms" do
      inventory.set_config(target, 'ssh', 'mac-algorithms' => ['defaults'])

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:hmac]).to match_array(Net::SSH::Transport::Algorithms::DEFAULT_ALGORITHMS[:hmac])
      end

      subject.connect
    end

    it "passes proxyjump options" do
      inventory.set_config(target, 'ssh', 'proxyjump' => 'jump.example.com')

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:proxy]).to be_instance_of(Net::SSH::Proxy::Jump)
      end
      subject.connect
    end

    it "performs secure host key verification by default" do
      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:verify_host_key]).to be_instance_of(Net::SSH::Verifiers::Always)
      end
      subject.connect
    end

    it "downgrades to lenient if host-key-check is false" do
      inventory.set_config(target, 'ssh', 'host-key-check' => false)

      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:verify_host_key]).to be_instance_of(Net::SSH::Verifiers::Never)
      end
      subject.connect
    end

    it "defers to SSH config if host-key-check is unset" do
      expect(Net::SSH::Config).to receive(:for).and_return(strict_host_key_checking: false)
      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:verify_host_key]).to be_instance_of(Net::SSH::Verifiers::AcceptNewOrLocalTunnel)
      end
      subject.connect
    end

    it "ignores SSH config if host-key-check is set" do
      inventory.set_config(target, 'ssh', 'host-key-check' => false)

      expect(Net::SSH::Config).to receive(:for).and_return(strict_host_key_checking: true)
      allow(Net::SSH).to receive(:start) do |_, _, options|
        expect(options[:verify_host_key]).to be_instance_of(Net::SSH::Verifiers::Never)
      end
      subject.connect
    end

    it "rejects the connection if host key verification fails" do
      allow(Net::SSH).to receive(:start)
        .and_raise(Net::SSH::HostKeyUnknown, "fingerprint is unknown")
      expect_node_error(Bolt::Node::ConnectError,
                        'HOST_KEY_ERROR',
                        /Host key verification failed/) do
        subject.connect
      end
    end

    it "raises ConnectError if authentication fails" do
      inventory.set_config(target, 'ssh', 'host-key-check' => false)

      allow(Net::SSH).to receive(:start)
        .and_raise(Net::SSH::AuthenticationFailed, "Authentication failed for foo@bar.com")
      expect_node_error(Bolt::Node::ConnectError,
                        'AUTH_ERROR',
                        /Authentication failed for foo@bar.com/) do
        subject.connect
      end
    end
  end

  context "when constructing a shell" do
    it "uses Bash as the default" do
      expect(subject.shell).to be_instance_of(Bolt::Shell::Bash)
    end

    %w[zsh ksh bash dash sh].each do |login_shell|
      it "uses Bash when login-shell is #{login_shell}" do
        inventory.set_config(target, 'ssh', 'login-shell' => login_shell)
        expect(subject.shell).to be_instance_of(Bolt::Shell::Bash)
      end
    end

    it "uses Powershell when login-shell is powershell" do
      inventory.set_config(target, 'ssh', 'login-shell' => 'powershell')
      expect(subject.shell).to be_instance_of(Bolt::Shell::Powershell)
    end
  end
end
