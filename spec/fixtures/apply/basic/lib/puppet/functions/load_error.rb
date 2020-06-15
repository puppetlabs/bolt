# frozen_string_literal: true

# This should raise a LoadError, as it's not a real gem
require 'fake'

Puppet::Functions.create_function(:load_error) do
  def load_error
    puts 'error'
  end
end
