# frozen_string_literal: true

require 'spec_helper'
require 'bolt/inventory'
require 'bolt/shell/powershell'

describe Bolt::Shell::Powershell do
  let(:inventory) { Bolt::Inventory.empty }
  let(:target) { inventory.get_target('winrm://foo.example.com') }
  let(:connection) { double('connection', user: 'Administrator') }
  let(:shell) { Bolt::Shell::Powershell.new(target, connection) }
  let(:status) { double('status', alive: false?, value: 0) }
  let(:ps_version) { double('node_output', stdout: StringIO.new("2\n")) }

  def mock_result(stdout: "", stderr: "", exitcode: 0)
    _, in_w = IO.pipe
    out_r, out_w = IO.pipe
    err_r, err_w = IO.pipe
    th = Thread.new do
      out_w.write(stdout)
      err_w.write(stderr)
      out_w.close
      err_w.close
      exitcode
    end
    [in_w, out_r, err_r, th]
  end

  before :each do
    allow(connection).to receive(:execute).and_return(mock_result)
    allow(connection).to receive(:max_command_length).and_return(256)
  end

  it "provides the 'powershell' feature" do
    expect(shell.provided_features).to eq(['powershell'])
  end

  describe "#default_input_method" do
    it "defaults to 'powershell' for a .ps1 file" do
      expect(shell.default_input_method('foo.ps1')).to eq('powershell')
    end

    it "defaults to 'both' for other files" do
      expect(shell.default_input_method('foo')).to eq('both')
      expect(shell.default_input_method('foo.rb')).to eq('both')
      expect(shell.default_input_method('foo.py')).to eq('both')
    end
  end

  describe "#validate_ps_version" do
    it "warns when PSVersionTable reports less than 3" do
      allow(shell).to receive(:execute)
        .with("$PSVersionTable.PSVersion.Major")
        .and_return(ps_version)

      shell.validate_ps_version
      expect(@log_output.readlines).to include(/Detected PowerShell 2 on/)
    end
  end

  describe "#validate_extensions" do
    it "fails if the extension isn't in the list" do
      ext = File.extname('foo.bar')
      expect { shell.validate_extensions(ext) }.to raise_error(/File extension \.bar is not enabled/)
    end

    it "fails if there is no extension" do
      ext = File.extname('foo')
      expect { shell.validate_extensions(ext) }.to raise_error(/File extension  is not enabled/)
    end

    it "allows the extension if it's in the list" do
      ext = File.extname('foo.rb')
      expect(shell.validate_extensions(ext)).to be_nil
    end

    it "allows the extension if it's in the list without a dot" do
      inventory.set_config(target, [target.transport, 'extensions'], ['py'])
      ext = File.extname('foo.py')
      expect(shell.validate_extensions(ext)).to be_nil
    end

    it "allows the extension if an interpreter is specified for it" do
      inventory.set_config(target, [target.transport, 'interpreters'], '.py' => 'C:\python.exe')
      ext = File.extname('foo.py')
      expect(shell.validate_extensions(ext)).to be_nil
    end
  end
end
