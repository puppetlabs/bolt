# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/docker'

describe Bolt::Transport::Docker do
  let(:docker) { described_class.new }
  let(:target) { double('target') }

  describe '#provided_features' do
    it 'returns shell feature' do
      expect(docker.provided_features).to include('shell')
    end
  end

  describe '#with_connection' do
    it 'creates a connection, connects, and yields it' do
      conn = double('connection')
      allow(Bolt::Transport::Docker::Connection).to receive(:new).and_return(conn)
      allow(conn).to receive(:connect)
      expect { |b| docker.with_connection(target, &b) }.to yield_with_args(conn)
    end
  end
end
