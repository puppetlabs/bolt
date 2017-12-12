linux_provision = <<SCRIPT
echo "vagrant ALL=(ALL) ALL" > /etc/sudoers.d/vagrant
SCRIPT

windows_enable_winrm_ssl = <<SCRIPT
$thumbprint = "B888D0548D394D9678131A36A4869E4C56F20E4F"
Import-PfxCertificate -FilePath C:\\cert.pfx -CertStoreLocation cert:\\LocalMachine\\My -Password (ConvertTo-SecureString -String vagrant -Force -AsPlainText)
New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address='*';Transport="HTTPS"} -ValueSet @{Hostname="localhost";CertificateThumbprint="$thumbprint"}
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.define :windows do |windows|
    windows.vm.box = "mwrock/WindowsNano"
    windows.vm.network :forwarded_port, guest: 22, host: 2222, id: "ssh"
    windows.vm.guest = :windows
    windows.vm.provision "file", source: "resources/cert.pfx", destination: 'C:\cert.pfx'
    windows.vm.provision "shell", privileged: true, inline: windows_enable_winrm_ssl
    windows.vm.communicator = "winrm"
  end

  config.vm.define :linux do |linux|
    linux.vm.box = "bento/centos-6.7"
    linux.vm.network :forwarded_port, guest: 22, host: 2224, id: "ssh"
    linux.vm.provision "shell", inline: linux_provision
  end
end
