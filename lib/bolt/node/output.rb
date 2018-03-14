# frozen_string_literal: true

require 'json'
require 'bolt/result'

module Bolt
  class Node
    class Output
      attr_reader :stdout, :stderr
      attr_accessor :exit_code

      def initialize
        @stdout = StringIO.new
        @stderr = StringIO.new
        @exit_code = 'unkown'
      end
    end
  end
end
