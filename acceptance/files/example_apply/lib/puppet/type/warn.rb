# frozen_string_literal: true

Puppet::Type.newtype(:warn) do
  @doc = "Sends a warning message to the agent run-time log."

  newproperty(:message, idempotent: false) do
    desc "The message to be sent to the log."
    def sync
      provider.warn(should)
    end

    def retrieve
      :absent
    end

    def insync?(_is_value)
      false
    end

    defaultto { @resource[:name] }
  end

  newparam(:name) do
    desc "An arbitrary tag for your own reference; the name of the message."
    isnamevar
  end
end
