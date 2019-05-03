# frozen_string_literal: true

module BoltSpec
  class EventCollector
    attr_reader :events

    def initialize
      @events = []
    end

    def handle_event(event)
      @events << event
    end

    def results
      @events.select { |event| event[:type] == :node_result }.map { |event| event[:result] }
    end
  end
end
