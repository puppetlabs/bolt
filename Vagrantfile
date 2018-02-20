windows_enable_winrm_ssl = <<SCRIPT
($cert = Import-PfxCertificate -FilePath C:\\cert.pfx -CertStoreLocation cert:\\LocalMachine\\My -Password (ConvertTo-SecureString -String vagrant -Force -AsPlainText)) | Format-List
New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address='*';Transport='HTTPS'} -ValueSet @{Hostname='localhost';CertificateThumbprint=$cert.Thumbprint} | Format-List
New-NetFirewallRule -DisplayName 'Windows Remote Management (HTTPS-In)' -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow | Format-List
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.define :windows do |windows|
    windows.vm.box = "mwrock/WindowsNano"
    windows.vm.guest = :windows
    windows.vm.communicator = "winrm"
    windows.vm.network :forwarded_port, guest: 22, host: 2222, id: "ssh", disabled: true
    windows.vm.network :forwarded_port, guest: 5985, host: 25985, host_ip: "127.0.0.1", id: "winrm"
    windows.vm.network :forwarded_port, guest: 5986, host: 25986, host_ip: "127.0.0.1", id: "winrm-ssl"
    windows.vm.provision "file", source: "resources/cert.pfx", destination: 'C:\cert.pfx'
    windows.vm.provision "shell", privileged: true, inline: windows_enable_winrm_ssl
    windows.vm.provider "virtualbox" do |vb|
      vb.gui = false
    end
  end
end
