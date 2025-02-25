# frozen_string_literal: true

Puppet::Util::Log.newdesttype :stderr do
  def initialize
    # Flush output immediately.
    $stderr.sync = true
  end

  # Emits message as a single line of JSON mapping level to message string.
  def handle(msg)
    str = msg.respond_to?(:multiline) ? msg.multiline : msg.to_s
    str = "#{msg.source}: #{str}" unless msg.source == "Puppet"
    warn({ level: msg.level, message: str }.to_json)
  end
end
