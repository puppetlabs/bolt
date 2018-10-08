# frozen_string_literal: true

windows_provision = <<SCRIPT
# add the bolt user account
($user = New-LocalUser -Name bolt -Password (ConvertTo-SecureString -String bolt -Force -AsPlainText)) | Format-List
# add the bolt user to the 'Remote Management Users' group
Add-LocalGroupMember -Group 'Remote Management Users' -Member $user

# import the certificate to be used for the winrm-ssl
($cert = Import-PfxCertificate -FilePath C:\\cert.pfx -CertStoreLocation cert:\\LocalMachine\\My -Password (ConvertTo-SecureString -String bolt -Force -AsPlainText)) | Format-List

# add the winrm-ssl listener
New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address='*';Transport='HTTPS'} -ValueSet @{Hostname='localhost';CertificateThumbprint=$cert.Thumbprint} | Format-List

# add a firewall rule allowing access to the winrm-ssl port (TCP port 5986)
New-NetFirewallRule -DisplayName 'Windows Remote Management (HTTPS-In)' -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow | Format-List
SCRIPT

linux_provision = <<SCRIPT
# add the bolt & test user accounts
useradd -m bolt && echo bolt | passwd --stdin bolt
useradd -m test

# let the bolt user use sudo
echo 'bolt ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/bolt

# configure public key authentication for the bolt user
mkdir -p -m 0700 /home/bolt/.ssh
cp id_rsa.pub /home/bolt/.ssh/authorized_keys
chown -R bolt:bolt /home/bolt/.ssh
chmod 600 /home/bolt/.ssh/authorized_keys
SCRIPT

Vagrant.configure('2') do |config|
  config.vm.define :windows do |windows|
    windows.vm.box = 'mwrock/WindowsNano'
    windows.vm.guest = :windows
    windows.vm.communicator = 'winrm'
    windows.vm.network :forwarded_port, guest: 22, host: 2222, id: 'ssh', disabled: true
    windows.vm.network :forwarded_port, guest: 5985, host: 25985, host_ip: '127.0.0.1', id: 'winrm'
    windows.vm.network :forwarded_port, guest: 5986, host: 25986, host_ip: '127.0.0.1', id: 'winrm-ssl'
    windows.vm.provision 'file', source: 'resources/cert.pfx', destination: 'C:\cert.pfx'
    windows.vm.provision 'shell', privileged: true, inline: windows_provision
    windows.vm.provider 'virtualbox' do |vb|
      vb.gui = false
    end
  end

  config.vm.define :windows5 do |windows|
    windows.vm.box = "jacqinthebox/windowsserver2016core"
    windows.vm.guest = :windows
    windows.vm.communicator = "winrm"
    windows.vm.network :forwarded_port, guest: 5985, host: 35985, host_ip: '127.0.0.1', id: 'winrm'
    windows.vm.provision 'shell', privileged: true, inline: 'slmgr /rearm'
    windows.vm.provider "virtualbox" do |vb|
      vb.gui = false
    end
  end

  config.vm.define :windows6 do |windows|
    windows.vm.box = "jacqinthebox/windowsserver2016core"
    windows.vm.guest = :windows
    windows.vm.communicator = "winrm"
    windows.vm.network :forwarded_port, guest: 5985, host: 35986, host_ip: '127.0.0.1', id: 'winrm'
    windows.vm.provision 'shell', privileged: true, inline: 'slmgr /rearm'
    windows.vm.provider "virtualbox" do |vb|
      vb.gui = false
    end
  end

  if ENV['BOLT_TEST_USE_VAGRANT']
    config.vm.define :linux do |linux|
      linux.vm.box = 'bento/centos-6.7'
      linux.vm.network :forwarded_port, guest: 22, host: 20022, host_ip: '127.0.0.1', id: 'ssh'
      linux.vm.provision 'file', source: 'spec/fixtures/keys/id_rsa.pub', destination: 'id_rsa.pub'
      linux.vm.provision 'shell', inline: linux_provision
    end
  end
end
