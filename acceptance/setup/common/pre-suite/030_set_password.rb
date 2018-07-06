# frozen_string_literal: true

require 'bolt_setup_helper'

test_name "Set root/Administrator password to a known value" do
  extend Beaker::HostPrebuiltSteps
  extend Acceptance::BoltSetupHelper

  hosts.each do |host|
    case host['platform']
    when /windows/
      on host, "passwd #{winrm_user}", stdin: winrm_password
    when /osx/
      # Our VMs default to PermitRootLogin prohibit-password
      on host, 'echo "PermitRootLogin yes" >> /etc/ssh/sshd_config' if ssh_user == 'root'
      on host, "dscl . -passwd /Users/#{ssh_user}", stdin: ssh_password
    else
      # Some platforms support --stdin, but repeating it seems to work everywhere
      on host, "passwd #{ssh_user}", stdin: "#{ssh_password}\n#{ssh_password}"
    end
  end
end
