# frozen_string_literal: true

test_name "Set root/Administrator password to a known value" do
  extend Beaker::HostPrebuiltSteps

  hosts.each do |host|
    case host['platform']
    when /windows/
      on host, "passwd #{ENV['WINRM_USER']}", stdin: ENV['WINRM_PASSWORD']
    when /osx/
      # Our VMs default to PermitRootLogin prohibit-password
      on host, 'echo "PermitRootLogin yes" >> /etc/ssh/sshd_config' if ENV['SSH_USER'] == 'root'
      on host, "dscl . -passwd /Users/#{ENV['SSH_USER']}", stdin: ENV['SSH_PASSWORD']
    else
      # Some platforms support --stdin, but repeating it seems to work everywhere
      on host, "passwd #{ENV['SSH_USER']}", stdin: "#{ENV['SSH_PASSWORD']}\n#{ENV['SSH_PASSWORD']}"
    end
  end
end
