linux_provision = <<SCRIPT
echo "vagrant ALL=(ALL) ALL" > /etc/sudoers.d/vagrant
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.define :windows do |windows|
    windows.vm.box = "mwrock/WindowsNano"
    windows.vm.network :forwarded_port, guest: 22, host: 2222, id: "ssh"
    windows.vm.guest = :windows
    windows.vm.communicator = "winrm"
  end

  config.vm.define :linux do |linux|
    linux.vm.box = "bento/centos-6.7"
    linux.vm.network :forwarded_port, guest: 22, host: 2224, id: "ssh"
    linux.vm.provision "shell", inline: linux_provision
  end
end
