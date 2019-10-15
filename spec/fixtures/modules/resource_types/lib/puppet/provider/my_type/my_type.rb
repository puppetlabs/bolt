# frozen_string_literal: true

Puppet::Type.type(:my_type).provide(:ruby) do
  desc "Empty provider"

  def self.instances
    []
  end
end
