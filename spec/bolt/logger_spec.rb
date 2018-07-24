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
  end

  describe '::configure' do
    let(:appenders) {
      {
        'file:/bolt.log' => {
        },
        'file:/debug.log' => {
          level: :debug,
          append: false
        }
      }
    }

    before :each do
      Logging.reset
      Bolt::Logger.initialize_logging
    end

    it 'sets the root logger level to :all' do
      Bolt::Logger.configure({}, true)

      expect(Logging.logger[:root].level).to eq(Logging.level_num(:all))
    end

    it 'creates the console appender with the expected properties' do
      expect(Logging.appenders['console']).to be_nil

      Bolt::Logger.configure({}, true)

      console_appender = Logging.appenders['console']

      expect(Logging.logger[:root].appenders).to eq([console_appender])

      expect(console_appender).not_to be_nil
      expect(console_appender.class).to eq(Logging::Appenders::Stderr)
      expect(console_appender.level).to eq(Logging.level_num(:notice))
      expect(console_appender.layout.color_scheme).to eq(Logging::ColorScheme['bolt'])
    end

    it 'overrides the level of the console appender if specified' do
      appenders = { 'console' => { level: :warn } }

      Bolt::Logger.configure(appenders, true)

      expect(Logging.appenders['console'].level).to eq(Logging.level_num(:warn))
    end

    it 'disables color if specified' do
      Bolt::Logger.configure({}, false)

      console_appender = Logging.appenders['console']

      expect(console_appender.layout.color_scheme).to be_nil
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

      Bolt::Logger.configure(appenders, true)
    end

    it 'adds all the additional appenders to the root logger' do
      expected_appenders = []

      expect(Logging.appenders)
        .to receive(:file).exactly(appenders.count) do |*args|
          appender = MockAppender.new(args.first)
          expected_appenders << appender
          appender
        end

      Bolt::Logger.configure(appenders, true)
      expected_appenders.unshift(Logging.appenders['console'])

      expect(Logging.logger[:root].appenders).to eq(expected_appenders)
    end

    it 'fails if any of the logs could not be opened' do
      appenders = { 'file:/nonexistent/file' => {} }

      expect { Bolt::Logger.configure(appenders, true) }.to raise_error(%r{^Failed to open log file:/nonexistent/file})
    end
  end
end
