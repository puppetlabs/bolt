# frozen_string_literal: true

module Bolt
  class Yarn
    attr_reader :fiber, :value, :index

    def initialize(fiber, index)
      @fiber = fiber
      @index = index
      @value = nil
    end

    def alive?
      fiber.alive?
    end

    def resume
      @value = fiber.resume
    end
  end
end
