# frozen_string_literal: true

module BoltSpec
  module Errors
    def expect_node_error(klass, issue_code, message)
      expect {
        yield
      }.to(raise_error { |ex|
        expect(ex).to be_a(klass)
        expect(ex.issue_code).to eq(issue_code)
        expect(ex.message).to match(message)
      })
    end
  end
end
