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

  describe '::valid_level?' do
    it 'identifies valid levels' do
      expect(Bolt::Logger.valid_level?(:fatal)).to be true
      expect(Bolt::Logger.valid_level?(:error)).to be true
      expect(Bolt::Logger.valid_level?(:warn)).to be true
      expect(Bolt::Logger.valid_level?(:notice)).to be true
      expect(Bolt::Logger.valid_level?(:info)).to be true
      expect(Bolt::Logger.valid_level?(:debug)).to be true
    end

    it 'rejects invalid levels' do
      expect(Bolt::Logger.valid_level?(:warning)).to be false
      expect(Bolt::Logger.valid_level?(:trace)).to be false
      expect(Bolt::Logger.valid_level?(:loud)).to be false
      expect(Bolt::Logger.valid_level?(:silent)).to be false
    end
  end

  describe '::lower_level?' do
    it 'confirms lower levels' do
      expect(Bolt::Logger.lower_level?(:debug, :fatal)).to be true
      expect(Bolt::Logger.lower_level?(:debug, :error)).to be true
      expect(Bolt::Logger.lower_level?(:debug, :warn)).to be true
      expect(Bolt::Logger.lower_level?(:debug, :notice)).to be true
      expect(Bolt::Logger.lower_level?(:debug, :info)).to be true

      expect(Bolt::Logger.lower_level?(:info, :fatal)).to be true
      expect(Bolt::Logger.lower_level?(:info, :error)).to be true
      expect(Bolt::Logger.lower_level?(:info, :warn)).to be true
      expect(Bolt::Logger.lower_level?(:info, :notice)).to be true

      expect(Bolt::Logger.lower_level?(:notice, :fatal)).to be true
      expect(Bolt::Logger.lower_level?(:notice, :error)).to be true
      expect(Bolt::Logger.lower_level?(:notice, :warn)).to be true

      expect(Bolt::Logger.lower_level?(:warn, :fatal)).to be true
      expect(Bolt::Logger.lower_level?(:warn, :error)).to be true

      expect(Bolt::Logger.lower_level?(:error, :fatal)).to be true
    end

    it 'rejects higher or equal levels' do
      expect(Bolt::Logger.lower_level?(:fatal, :fatal)).to be false
      expect(Bolt::Logger.lower_level?(:fatal, :error)).to be false
      expect(Bolt::Logger.lower_level?(:fatal, :warn)).to be false
      expect(Bolt::Logger.lower_level?(:fatal, :notice)).to be false
      expect(Bolt::Logger.lower_level?(:fatal, :info)).to be false
      expect(Bolt::Logger.lower_level?(:fatal, :debug)).to be false

      expect(Bolt::Logger.lower_level?(:error, :error)).to be false
      expect(Bolt::Logger.lower_level?(:error, :warn)).to be false
      expect(Bolt::Logger.lower_level?(:error, :notice)).to be false
      expect(Bolt::Logger.lower_level?(:error, :info)).to be false
      expect(Bolt::Logger.lower_level?(:error, :debug)).to be false

      expect(Bolt::Logger.lower_level?(:warn, :warn)).to be false
      expect(Bolt::Logger.lower_level?(:warn, :notice)).to be false
      expect(Bolt::Logger.lower_level?(:warn, :info)).to be false
      expect(Bolt::Logger.lower_level?(:warn, :debug)).to be false

      expect(Bolt::Logger.lower_level?(:notice, :notice)).to be false
      expect(Bolt::Logger.lower_level?(:notice, :info)).to be false
      expect(Bolt::Logger.lower_level?(:notice, :debug)).to be false

      expect(Bolt::Logger.lower_level?(:info, :info)).to be false
      expect(Bolt::Logger.lower_level?(:info, :debug)).to be false

      expect(Bolt::Logger.lower_level?(:debug, :debug)).to be false
    end
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
      expect(console_appender.level).to eq(Logging.level_num(:warn))
      expect(console_appender.layout.color_scheme).to eq(Logging::ColorScheme['bolt'])
    end

    it 'overrides the level of the console appender if specified' do
      appenders = { 'console' => { level: :info } }

      Bolt::Logger.configure(appenders, true)

      expect(Logging.appenders['console'].level).to eq(Logging.level_num(:info))
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
