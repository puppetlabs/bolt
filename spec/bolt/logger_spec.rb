# frozen_string_literal: true

require 'spec_helper'

describe Bolt::Logger do
  class MockAppender < Logging::Appender
    def initialize(*args)
      @name = args.first
    end
  end

  before :all do
    # save the root logger appenders so as not to interfere with logging helpers
    @saved_appenders = Logging.logger[:root].appenders.map { |appender|
      Logging.appenders.remove(appender.name)
    }
  end

  after :all do
    Logging.reset
    Bolt::Logger.initialize_logging
    @saved_appenders.each do |appender|
      Logging.appenders[appender.name] = appender
    end
    Logging.logger[:root].appenders = @saved_appenders
  end

  describe '::initialize_logging' do
    before :each do
      Logging.reset
    end

    it 'sets up the expected logging levels' do
      expect(Logging::LEVELS).to be_empty

      Bolt::Logger.initialize_logging

      expect(Logging::LEVELS).to eq(
        %w[debug info notice warn error fatal any].each_with_object({}) { |l, h| h[l] = h.count }
      )
    end

    it 'creates the console appender with the expected properties' do
      expect(Logging.appenders['console']).to be_nil

      Bolt::Logger.initialize_logging

      console_appender = Logging.appenders['console']

      expect(console_appender).not_to be_nil
      expect(console_appender.class).to eq(Logging::Appenders::Stderr)
      expect(console_appender.level).to eq(Logging.level_num(:notice))
    end

    it 'adds the console appender to the root logger' do
      # this initializes logging, se we need to reset it again
      expect(Logging.logger[:root].appenders).to be_empty
      Logging.reset

      Bolt::Logger.initialize_logging

      console_appender = Logging.appenders['console']

      expect(Logging.logger[:root].appenders).to eq([console_appender])
    end

    it 'sets the root logger level to :all' do
      Bolt::Logger.initialize_logging

      expect(Logging.logger[:root].level).to eq(Logging.level_num(:all))
    end
  end

  describe '::configure' do
    let(:config) {
      Bolt::Config.new(
        log: {
          'file:/bolt.log' => {
          },
          'file:/debug.log' => {
            level: :debug,
            append: false
          }
        }
      )
    }

    before :each do
      Logging.reset
      Bolt::Logger.initialize_logging
    end

    it 'sets the level of the console appender' do
      config[:log] = { 'console' => { level: :foo } }

      expect(Logging.appenders['console']).to receive(:level=).with(:foo)

      Bolt::Logger.configure(config)
    end

    it 'creates all the additional appenders with expected properties' do
      expect(Logging.appenders)
        .to receive(:file)
        .with('file:/bolt.log', hash_including(filename: '/bolt.log', truncate: false)) do |*args|
          appender = MockAppender.new(args.first)
          expect(appender).not_to receive(:level)
          appender
        end

      expect(Logging.appenders)
        .to receive(:file)
        .with('file:/debug.log', hash_including(filename: '/debug.log', truncate: true)) do |*args|
          appender = MockAppender.new(args.first)
          expect(appender).to receive(:level=).with(:debug)
          appender
        end

      Bolt::Logger.configure(config)
    end

    it 'adds all the additional appenders to the root logger' do
      appenders = [Logging.appenders['console']]

      expect(Logging.appenders)
        .to receive(:file).exactly(config[:log].count - 1) do |*args|
          appender = MockAppender.new(args.first)
          appenders << appender
          appender
        end

      Bolt::Logger.configure(config)

      expect(Logging.logger[:root].appenders).to eq(appenders)
    end

    it 'fails if any of the logs could not be opened' do
      config[:log] = { 'file:/nonexistent/file' => {} }

      expect { Bolt::Logger.configure(config) }.to raise_error(%r{^Failed to open log file:/nonexistent/file})
    end
  end
end
