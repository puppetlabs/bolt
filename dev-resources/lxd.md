### Provisioning for LXD tests
Use the LXD VMs specified in the Vagrantfile like so:
```
vagrant up lxc_remote
vagrant up lxd
vagrant ssh lxd
cd bolt/
bundle config set --local path 'vendor/bundle'
bundle exec rake tests:lxd
bundle exec rake tests:lxc_remote
```
The VM mounts the current Bolt directory to the VM at `/home/bolt/bolt`. Any changes you make
locally will be synced to the VM automatically. This is an excellent way to test the LXD transport
without installing LXD locally.

**NOTE:** Ensure that you have Ruby 2.7 installed locally, and rubygems installed to
`vendor/bundle/ruby/2.7.0`.

