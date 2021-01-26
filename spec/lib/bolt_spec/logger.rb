# frozen_string_literal: true

require 'logging'

module BoltSpec
  module Logger
    def stub_logger
      @mock_logger = instance_double("Logging.logger")
      allow(Bolt::Logger).to receive(:logger).and_return(mock_logger)
      allow(@mock_logger).to receive(:[]).and_return(mock_logger)
      # These are allowed since we don't test them and the ssh library uses them
      allow(@mock_logger).to receive(:trace)
      allow(@mock_logger).to receive(:debug)
      allow(@mock_logger).to receive(:debug?)
      allow(@mock_logger).to receive(:info?)
      allow(@mock_logger).to receive(:level=)
    end

    def mock_logger
      @mock_logger
    end
  end
end
