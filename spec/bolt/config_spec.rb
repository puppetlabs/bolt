require 'spec_helper'
require 'bolt/config'

describe Bolt::Config do
  let(:config) { Bolt::Config.new }

  describe "when initializing" do
    it "accepts keyword values" do
      config = Bolt::Config.new(concurrency: 200)
      expect(config.concurrency).to eq(200)
    end

    it "uses a default value when none is given" do
      config = Bolt::Config.new
      expect(config.concurrency).to eq(100)
    end

    it "does not use a default value when nil is given" do
      config = Bolt::Config.new(concurrency: nil)
      expect(config.concurrency).to eq(nil)
    end

    it "rejects unknown keys" do
      expect {
        Bolt::Config.new(what: 'why')
      }.to raise_error(NameError)
    end
  end

  describe "load_file" do
    let(:default_path) { File.expand_path(File.join('~', '.puppetlabs', 'bolt.yaml')) }
    let(:alt_path) { File.expand_path(File.join('~', '.puppetlabs', 'bolt.yml')) }

    it "loads from a default file" do
      expect(File).to receive(:exist?).with(default_path).and_return(true)
      expect(File).to receive(:exist?).with(alt_path).and_return(false)
      expect(File).to receive(:open).with(default_path, 'r:UTF-8').and_raise(Errno::ENOENT)
      config.load_file(nil)
    end

    it "falls back to the old default file" do
      expect(File).to receive(:exist?).with(default_path).and_return(false)
      expect(File).to receive(:exist?).with(alt_path).and_return(true)
      expect(File).to receive(:open).with(alt_path, 'r:UTF-8').and_raise(Errno::ENOENT)
      config.load_file(nil)
    end

    it "warns if both defaults exist, and uses the new default" do
      logger = double('logger')
      expect(logger).to receive(:warn).with("Config files found at #{default_path}, #{alt_path}, using the first")
      expect(Logger).to receive(:new).and_return(logger)

      expect(File).to receive(:exist?).with(default_path).and_return(true)
      expect(File).to receive(:exist?).with(alt_path).and_return(true)
      expect(File).to receive(:open).with(default_path, 'r:UTF-8').and_raise(Errno::ENOENT)

      config.load_file(nil)
    end

    it "loads from the specified file" do
      path = 'does not exist'
      expanded_path = File.expand_path(path)

      expect(File).not_to receive(:exist?).with(default_path)
      expect(File).not_to receive(:exist?).with(alt_path)
      expect(File).to receive(:open).with(expanded_path, 'r:UTF-8').and_raise(Errno::ENOENT)
      expect { config.load_file(path) }.to raise_error(Bolt::CLIError)
    end
  end

  describe "validate" do
    it "accepts integers for connection-timeout" do
      config = {
        transports: {
          ssh: { connect_timeout: 42 },
          winrm: { connect_timeout: 999 },
          pcp: {}
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.not_to raise_error
    end

    it "does not accept values that are not integers" do
      config = {
        transports: {
          ssh: { connect_timeout: '42s' }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::CLIError)
    end
  end
end
