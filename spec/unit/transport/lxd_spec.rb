# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/lxd'

describe Bolt::Transport::LXD do
  let(:lxd) { described_class.new }
  let(:target) { double('target') }

  describe '#provided_features' do
    it 'returns shell feature' do
      expect(lxd.provided_features).to include('shell')
    end
  end

  describe '#with_connection' do
    it 'creates a connection, connects, and yields it' do
      conn = double('connection')
      allow(Bolt::Transport::LXD::Connection).to receive(:new).and_return(conn)
      allow(conn).to receive(:connect)
      expect { |b| lxd.with_connection(target, &b) }.to yield_with_args(conn)
    end
  end
end
