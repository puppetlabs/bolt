# frozen_string_literal: true

require 'spec_helper'

class MockAppender < Logging::Appender
  def initialize(*args)
    @name = args.first
  end
end

describe Bolt::Logger do
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

    it 'sets up the log levels' do
      expect(Logging::LEVELS).to be_empty

      Bolt::Logger.initialize_logging

      expect(Logging::LEVELS).not_to be_empty
    end
  end

  describe '::deprecate' do
    let(:analytics) { Bolt::Analytics::NoopClient.new }

    it 'submits an analytics event' do
      allow(Bolt::Logger).to receive(:configured?).and_return(true)
      expect(analytics).to receive(:event).with('Warn', 'deprecation', { label: "We've got clearance Clarence" })
      Bolt::Logger.analytics = analytics
      Bolt::Logger.deprecate("We've got clearance Clarence", "Roger Roger")
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

  describe '::flush_queue' do
    let(:mock_logger) do
      double('mock_logger', warn: nil)
    end

    it 'flushes the message queue and logs all queued messages' do
      allow(Bolt::Logger).to receive(:configured?).and_return(false)
      Bolt::Logger.warn("sarcasm", "May contain sarcasm")
      Bolt::Logger.warn("caution", "Proceed with caution")

      expect(Bolt::Logger.instance_variable_get(:@message_queue).size).to eq(2)

      allow(Bolt::Logger).to receive(:configured?).and_return(true)
      allow(Bolt::Logger).to receive(:logger).and_return(mock_logger)
      expect(mock_logger).to receive(:warn).with(/May contain sarcasm/)
      expect(mock_logger).to receive(:warn).with(/Proceed with caution/)
      Bolt::Logger.flush_queue

      expect(Bolt::Logger.instance_variable_get(:@message_queue).size).to eq(0)
    end
  end

  describe 'message queue' do
    it 'queues messages when not configured' do
      allow(Bolt::Logger).to receive(:configured?).and_return(false)
      expect(Bolt::Logger).not_to receive(:logger)
      expect(Logging).not_to receive(:logger)

      Bolt::Logger.warn("bolt_rating", "Comic mischief, Mild fantasy humor")
      Bolt::Logger.warn_once("stroller_warning", "Remove child before folding")
      Bolt::Logger.deprecate("deprecated_test", "This test has been deprecated")
      Bolt::Logger.deprecate_once("another_deprecated_test", "Did I stutter?")
      Bolt::Logger.info("A dog's noseprint is unique")
      Bolt::Logger.debug("But have you met their siblings A, B, and C bug?")

      expect(Bolt::Logger.instance_variable_get(:@message_queue)).to match_array(
        [
          { type: :warn, id: "bolt_rating", msg: "Comic mischief, Mild fantasy humor [ID: bolt_rating]" },
          { type: :warn_once, id: "stroller_warning", msg: "Remove child before folding [ID: stroller_warning]" },
          { type: :deprecate, id: "deprecated_test", msg: "This test has been deprecated [ID: deprecated_test]" },
          { type: :deprecate_once, id: "another_deprecated_test", msg: "Did I stutter? [ID: another_deprecated_test]" },
          { type: :info, id: nil, msg: "A dog's noseprint is unique" },
          { type: :debug, id: nil, msg: "But have you met their siblings A, B, and C bug?" }
        ]
      )
    end
  end
end
