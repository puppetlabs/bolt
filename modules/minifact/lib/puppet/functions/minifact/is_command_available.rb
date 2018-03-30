# frozen_string_literal: true

# Checks whether the given command is available on the local host. Calls
# the Puppet::Util.which function, returns true if that function returns
# a non-nil value, false otherwise.
Puppet::Functions.create_function(:'minifact::is_command_available') do
  dispatch :check_command do
    param 'String[1]', :command
    return_type 'Boolean'
  end

  def check_command(command)
    !Puppet::Util.which(command).nil?
  end
end
