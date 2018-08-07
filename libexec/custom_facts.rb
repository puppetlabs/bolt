#! /opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'json'
require 'puppet'
require 'puppet/module_tool/tar'
require 'tempfile'

args = JSON.parse(STDIN.read)

Dir.mktmpdir do |moduledir|
  Tempfile.open('plugins.tar.gz') do |plugins|
    File.binwrite(plugins, Base64.decode64(args['plugins']))
    Puppet::ModuleTool::Tar.instance.unpack(plugins, moduledir, Etc.getlogin || Etc.getpwuid.name)
  end

  Puppet.initialize_settings
  env = Puppet.lookup(:environments).get('production').override_with(modulepath: [moduledir])
  env.each_plugin_directory do |dir|
    $LOAD_PATH << dir unless $LOAD_PATH.include?(dir)
  end

  dirs = []
  external_dirs = []
  env.modules.each do |mod|
    dirs << File.join(mod.plugins, 'facter') if mod.plugins?
    external_dirs << mod.pluginfacts if mod.pluginfacts?
  end

  Facter.reset
  Facter.search(*dirs) unless dirs.empty?
  Facter.search_external(external_dirs)

  if Puppet.respond_to? :initialize_facts
    Puppet.initialize_facts
  else
    Facter.add(:puppetversion) do
      setcode { Puppet.version.to_s }
    end
  end

  puts(Facter.to_hash.to_json)
end
exit 0
