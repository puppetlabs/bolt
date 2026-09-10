# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/podman'

describe Bolt::Transport::Podman do
  let(:podman) { described_class.new }
  let(:target) { double('target') }

  describe '#with_connection' do
    it 'creates a connection, connects, and yields it' do
      conn = double('connection')
      allow(Bolt::Transport::Podman::Connection).to receive(:new).and_return(conn)
      allow(conn).to receive(:connect)
      expect { |b| podman.with_connection(target, &b) }.to yield_with_args(conn)
    end
  end
end
