# frozen_string_literal: true

require 'json'
require 'bolt/result'

module Bolt
  class Node
    class Output
      attr_reader :stderr, :stdout, :merged_output
      attr_accessor :exit_code

      def initialize
        @stdout        = StringIO.new
        @stderr        = StringIO.new
        @merged_output = StringIO.new
        @exit_code     = 'unknown'
      end

      def to_h
        {
          'stdout'        => @stdout.string,
          'stderr'        => @stderr.string,
          'merged_output' => @merged_output.string,
          'exit_code'     => @exit_code
        }
      end
    end
  end
end
