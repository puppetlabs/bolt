# -*- mode: ruby -*-
# vi: set ft=ruby :

TARGETS = 2

Vagrant.configure(TARGETS) do |config|
  config.vm.box = "centos/7"
  config.ssh.forward_agent = true

  TARGETS.times do |i|
    config.vm.define "target#{i}" do |target|
      target.vm.hostname = "target#{i}"
      target.vm.network :private_network, ip: "10.0.0.#{100 + i}"
    end
  end
end