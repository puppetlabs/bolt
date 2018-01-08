# -*- mode: ruby -*-
# vi: set ft=ruby :

$nodes_count = 3

if ENV['NODES'].to_i > 0 && ENV['NODES']
  $nodes_count = ENV['NODES'].to_i
end

Vagrant.configure('2') do |config|
  config.vm.box = 'centos/7'
  config.ssh.forward_agent = true
  config.vm.network "private_network", type: "dhcp"

  (1..$nodes_count).each do |i|
    config.vm.define "node#{i}"
  end

  config.vm.define :windows do |windows|
    windows.vm.box = "mwrock/WindowsNano"
    windows.vm.guest = :windows
    windows.vm.communicator = "winrm"
  end
end
