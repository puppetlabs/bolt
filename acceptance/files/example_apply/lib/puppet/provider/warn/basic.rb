# frozen_string_literal: true

require 'puppet_x/util/warn'

Puppet::Type.type(:warn).provide(:basic) do
  desc 'Basic implementation of the warn type'

  confine another: "I'm"
  confine feature: :can_warn

  def warn(msg)
    PuppetX::Util.warn(msg)
  end
end
