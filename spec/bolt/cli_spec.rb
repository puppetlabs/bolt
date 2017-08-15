require 'spec_helper'
require 'bolt/cli'

describe "Bolt::CLI" do
  it "generates an error message if an unknown argument is given" do
    cli = Bolt::CLI.new(%w[--unknown])
    expect {
      cli.parse
    }.to raise_error(Bolt::CLIError, /unknown argument '--unknown'/)
  end

  it "includes unparsed arguments" do
    cli = Bolt::CLI.new(%w[exec --hosts foo])
    expect(cli.parse).to include(:leftovers => %w[exec])
  end

  describe "help" do
    it "generates help when no arguments are specified" do
      cli = Bolt::CLI.new([])
      expect {
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIExit)
      }.to output(/Runs ad-hoc tasks on your hosts/).to_stdout
    end

    it "accepts --help" do
      cli = Bolt::CLI.new(%w[--help])
      expect {
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIExit)
      }.to output(/Runs ad-hoc tasks on your hosts/).to_stdout
    end
  end

  describe "version" do
    it "emits a version string" do
      cli = Bolt::CLI.new(%w[--version])
      expect {
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIExit)
      }.to output(/\d+\.\d+\.\d+/).to_stdout
    end
  end

  describe "hosts" do
    it "accepts a single host" do
      cli = Bolt::CLI.new(%w[exec --hosts foo])
      expect(cli.parse).to include(:hosts => ['foo'])
    end

    it "accepts multiple hosts" do
      cli = Bolt::CLI.new(%w[exec --hosts foo bar])
      expect(cli.parse).to include(:hosts => ['foo', 'bar'])
    end

    it "generates an error message if no hosts given" do
      cli = Bolt::CLI.new(%w[exec --hosts])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option '--hosts' needs a parameter/)
    end

    it "generates an error message if hosts is omitted" do
      cli = Bolt::CLI.new(%w[exec])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option --hosts must be specified/)
    end

    describe "with winrm" do
      it "accepts 'winrm://host:port'" do
        uri = Bolt::CLI.parse_uri('winrm://neptune:55985')
        expect(uri.scheme).to eq('winrm')
        expect(uri.host).to eq('neptune')
        expect(uri.port).to eq(55985)
      end

      it "defaults the winrm port to 5985" do
        uri = Bolt::CLI.parse_uri('winrm://neptune')
        expect(uri.scheme).to eq('winrm')
        expect(uri.host).to eq('neptune')
        expect(uri.port).to eq(5985)
      end
    end

    describe "with ssh" do
      it "accepts 'ssh://host:port'" do
        uri = Bolt::CLI.parse_uri('ssh://pluto:2224')
        expect(uri.scheme).to eq('ssh')
        expect(uri.host).to eq('pluto')
        expect(uri.port).to eq(2224)
      end

      it "defaults the ssh port to 22" do
        uri = Bolt::CLI.parse_uri('ssh://pluto')
        expect(uri.scheme).to eq('ssh')
        expect(uri.host).to eq('pluto')
        expect(uri.port).to eq(22)
      end

      it "accepts 'host:port' without a scheme" do
        uri = Bolt::CLI.parse_uri('pluto:2224')
        expect(uri.scheme).to eq('ssh')
        expect(uri.host).to eq('pluto')
        expect(uri.port).to eq(2224)
      end

      it "defaults the ssh port to 22 without a scheme" do
        uri = Bolt::CLI.parse_uri('pluto')
        expect(uri.scheme).to eq('ssh')
        expect(uri.host).to eq('pluto')
        expect(uri.port).to eq(22)
      end
    end
  end

  describe "user" do
    it "accepts a user" do
      cli = Bolt::CLI.new(%w[exec --user root --hosts foo])
      expect(cli.parse).to include(:user => 'root')
    end

    it "generates an error message if no user value is given" do
      cli = Bolt::CLI.new(%w[exec --user --hosts foo])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option '--user' needs a parameter/)
    end
  end

  describe "password" do
    it "accepts a password" do
      cli = Bolt::CLI.new(%w[exec --password opensesame --hosts foo])
      expect(cli.parse).to include(:password => 'opensesame')
    end

    it "generates an error message if no password value is given" do
      cli = Bolt::CLI.new(%w[exec --password --hosts foo])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option '--password' needs a parameter/)
    end
  end

  describe "command" do
    it "interprets command=whoami as a task option" do
      cli = Bolt::CLI.new(%w[exec --hosts foo command=whoami])
      expect(cli.parse).to include(:task_options => { 'command' => 'whoami'})
      expect(cli.parse[:hosts]).to_not include('command=whoami')
      expect(cli.parse[:leftovers]).to_not include('command=whoami')
    end
  end
end
