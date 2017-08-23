require 'spec_helper'
require 'bolt/cli'

describe "Bolt::CLI" do
  it "generates an error message if an unknown argument is given" do
    cli = Bolt::CLI.new(%w[exec --unknown])
    expect {
      cli.parse
    }.to raise_error(Bolt::CLIError, /unknown argument '--unknown'/)
  end

  it "includes unparsed arguments" do
    cli = Bolt::CLI.new(%w[exec what --nodes foo])
    expect(cli.parse).to include(leftovers: %w[what])
  end

  describe "help" do
    it "generates help when no arguments are specified" do
      cli = Bolt::CLI.new([])
      expect {
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIExit)
      }.to output(/Runs ad-hoc tasks on your nodes/).to_stdout
    end

    it "accepts --help" do
      cli = Bolt::CLI.new(%w[--help])
      expect {
        expect {
          cli.parse
        }.to raise_error(Bolt::CLIExit)
      }.to output(/Runs ad-hoc tasks on your nodes/).to_stdout
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

  describe "nodes" do
    it "accepts a single node" do
      cli = Bolt::CLI.new(%w[exec --nodes foo])
      expect(cli.parse).to include(nodes: ['foo'])
    end

    it "accepts multiple nodes" do
      cli = Bolt::CLI.new(%w[exec --nodes foo bar])
      expect(cli.parse).to include(nodes: %w[foo bar])
    end

    it "generates an error message if no nodes given" do
      cli = Bolt::CLI.new(%w[exec --nodes])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option '--nodes' needs a parameter/)
    end

    it "generates an error message if nodes is omitted" do
      cli = Bolt::CLI.new(%w[exec])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option --nodes must be specified/)
    end
  end

  describe "user" do
    it "accepts a user" do
      cli = Bolt::CLI.new(%w[exec --user root --nodes foo])
      expect(cli.parse).to include(user: 'root')
    end

    it "generates an error message if no user value is given" do
      cli = Bolt::CLI.new(%w[exec --user --nodes foo])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option '--user' needs a parameter/)
    end
  end

  describe "password" do
    it "accepts a password" do
      cli = Bolt::CLI.new(%w[exec --password opensesame --nodes foo])
      expect(cli.parse).to include(password: 'opensesame')
    end

    it "generates an error message if no password value is given" do
      cli = Bolt::CLI.new(%w[exec --password --nodes foo])
      expect {
        cli.parse
      }.to raise_error(Bolt::CLIError, /option '--password' needs a parameter/)
    end
  end

  describe "command" do
    it "interprets command=whoami as a task option" do
      cli = Bolt::CLI.new(%w[exec --nodes foo command=whoami])
      expect(cli.parse).to include(task_options: { 'command' => 'whoami' })
      expect(cli.parse[:nodes]).to_not include('command=whoami')
      expect(cli.parse[:leftovers]).to_not include('command=whoami')
    end
  end

  it "distinguishes subcommands" do
    cli = Bolt::CLI.new(%w[script --nodes foo])
    expect(cli.parse).to include(mode: 'script')
  end
end
