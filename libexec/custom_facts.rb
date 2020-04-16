#! /opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'json'
require 'puppet'
require 'puppet/module_tool/tar'
require 'tempfile'

args = JSON.parse(STDIN.read)

Dir.mktmpdir do |puppet_root|
  # Create temporary directories for all core Puppet settings so we don't clobber
  # existing state or read from puppet.conf. Also create a temporary modulepath.
  moduledir = File.join(puppet_root, 'modules')
  Dir.mkdir(moduledir)
  cli = Puppet::Settings::REQUIRED_APP_SETTINGS.flat_map do |setting|
    ["--#{setting}", File.join(puppet_root, setting.to_s.chomp('dir'))]
  end
  cli << '--modulepath' << moduledir
  Puppet.initialize_settings(cli)

  Tempfile.open('plugins.tar.gz') do |plugins|
    File.binwrite(plugins, Base64.decode64(args['plugins']))
    user = Etc.getpwuid.nil? ? Etc.getlogin : Etc.getpwuid.name
    Puppet::ModuleTool::Tar.instance.unpack(plugins, moduledir, user)
  end

  env = Puppet.lookup(:environments).get('production')
  env.each_plugin_directory do |dir|
    $LOAD_PATH << dir unless $LOAD_PATH.include?(dir)
  end

  if (conn_info = args['_target'])
    unless (type = conn_info['remote-transport'])
      puts "Cannot collect facts for a remote target without knowing the remote-transport type."
      exit 1
    end

    begin
      require 'puppet/resource_api/transport'
    rescue LoadError
      msg = "Could not load 'puppet/resource_api/transport', puppet-resource_api "\
            "gem version 1.8.0 or greater is required on the proxy target"
      puts msg
      exit 1
    end

    # Transport.connect will modify this hash!
    transport_conn_info = conn_info.transform_keys(&:to_sym)
    transport = Puppet::ResourceApi::Transport.connect(type, transport_conn_info)
    Puppet::ResourceApi::Transport.inject_device(type, transport)

    Puppet[:facts_terminus] = :network_device
    Puppet[:certname] = conn_info['uri']
  end

  facts = Puppet::Node::Facts.indirection.find(SecureRandom.uuid, environment: env)

  facts.name = facts.values['clientcert']
  puts(facts.values.to_json)
end

exit 0
