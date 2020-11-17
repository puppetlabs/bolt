#! /opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'puppet'
require 'puppet/configurer'
require 'puppet/module_tool/tar'
require 'securerandom'
require 'tempfile'

args = JSON.parse(ARGV[0] ? File.read(ARGV[0]) : $stdin.read)

# Create temporary directories for all core Puppet settings so we don't clobber
# existing state or read from puppet.conf. Also create a temporary modulepath.
# Additionally include rundir, which gets its own initialization.
puppet_root = Dir.mktmpdir
moduledir = File.join(puppet_root, 'modules')
Dir.mkdir(moduledir)
cli = (Puppet::Settings::REQUIRED_APP_SETTINGS + [:rundir]).flat_map do |setting|
  ["--#{setting}", File.join(puppet_root, setting.to_s.chomp('dir'))]
end
cli << '--modulepath' << moduledir
Puppet.initialize_settings(cli)

# Avoid extraneous output
Puppet[:report] = false

# Make sure to apply the catalog
Puppet[:noop] = args['_noop'] || false
args['apply_settings'].each do |setting, value|
  Puppet[setting.to_sym] = value
end

Puppet[:default_file_terminus] = :file_server

exit_code = 0
begin
  # This happens implicitly when running the Configurer, but we make it explicit here. It creates the
  # directories we configured earlier.
  Puppet.settings.use(:main)

  Tempfile.open('plugins.tar.gz') do |plugins|
    File.binwrite(plugins, Base64.decode64(args['plugins']))
    user = Etc.getpwuid.nil? ? Etc.getlogin : Etc.getpwuid.name
    Puppet::ModuleTool::Tar.instance.unpack(plugins, moduledir, user)
  end

  env = Puppet.lookup(:environments).get('production')
  # Needed to ensure features are loaded
  env.each_plugin_directory do |dir|
    $LOAD_PATH << dir unless $LOAD_PATH.include?(dir)
  end

  if (conn_info = args['_target'])
    unless (type = conn_info['remote-transport'])
      puts "Cannot execute a catalog for a remote target without knowing it's the remote-transport type."
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
    Puppet[:certname] = conn_info['name']
  end

  # Ensure custom facts are available for provider suitability tests
  facts = Puppet::Node::Facts.indirection.find(SecureRandom.uuid, environment: env)

  report = if Puppet::Util::Package.versioncmp(Puppet.version, '5.0.0') > 0
             Puppet::Transaction::Report.new
           else
             Puppet::Transaction::Report.new('apply')
           end

  overrides = { current_environment: env,
                loaders: Puppet::Pops::Loaders.new(env) }
  overrides[:network_device] = true if args['_target']

  Puppet.override(overrides) do
    catalog = Puppet::Resource::Catalog.from_data_hash(args['catalog'])
    catalog.environment = env.name.to_s
    catalog.environment_instance = env
    if defined?(Puppet::Pops::Evaluator::DeferredResolver)
      # Only available in Puppet 6
      Puppet::Pops::Evaluator::DeferredResolver.resolve_and_replace(facts, catalog)
    end
    catalog = catalog.to_ral

    configurer = Puppet::Configurer.new
    configurer.run(catalog: catalog, report: report, pluginsync: false)
  end

  puts JSON.pretty_generate(report.to_data_hash)
  exit_code = report.exit_status != 1
ensure
  begin
    FileUtils.remove_dir(puppet_root)
  rescue Errno::ENOTEMPTY => e
    $stderr.puts("Could not cleanup temporary directory: #{e}")
  end
end

exit exit_code
