#! /opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'puppet'
require 'puppet/configurer'
require 'puppet/module_tool/tar'
require 'tempfile'

args = JSON.parse(ARGV[0] ? File.read(ARGV[0]) : STDIN.read)

Puppet.initialize_settings([])
run_mode = Puppet::Util::RunMode[:user]
Puppet.settings.initialize_app_defaults(Puppet::Settings.app_defaults_for_run_mode(run_mode))

Puppet::ApplicationSupport.push_application_context(run_mode)

# Avoid extraneous output
Puppet[:summarize] = false

# Don't interfere with the normal agent
Puppet[:report] = false
Puppet[:graph] = false

# Get a unique temporary path, but ensure the file doesn't exist or Puppet will report 'State got corrupted'
statefile = Tempfile.new('puppet-state')
Puppet[:statefile] = statefile.path
statefile.close!

# Make sure to apply the catalog
Puppet[:use_cached_catalog] = false
Puppet[:noop] = args['_noop'] || false
Puppet[:strict_environment_mode] = false

# The whole catalog
Puppet[:tags] = nil
Puppet[:skip_tags] = nil

# And nothing but the catalog
Puppet[:prerun_command] = nil
Puppet[:postrun_command] = nil

Puppet[:default_file_terminus] = :file_server

exit_code = 0
moduledir = Dir.mktmpdir
begin
  Tempfile.open('plugins.tar.gz') do |plugins|
    File.binwrite(plugins, Base64.decode64(args['plugins']))
    Puppet::ModuleTool::Tar.instance.unpack(plugins, moduledir, Etc.getlogin || Etc.getpwuid.name)
  end

  env = Puppet.lookup(:environments).get('production').override_with(modulepath: [moduledir])
  # Needed to ensure features are loaded
  env.each_plugin_directory do |dir|
    $LOAD_PATH << dir unless $LOAD_PATH.include?(dir)
  end

  # Ensure custom facts are available for provider suitability tests
  Puppet::Node::Facts.indirection.find('puppetversion', environment: env)

  report = if Puppet::Util::Package.versioncmp(Puppet.version, '5.0.0') > 0
             Puppet::Transaction::Report.new
           else
             Puppet::Transaction::Report.new('apply')
           end

  Puppet.override(current_environment: env,
                  environments: Puppet::Environments::Static.new(env),
                  loaders: Puppet::Pops::Loaders.new(env)) do
    catalog = Puppet::Resource::Catalog.from_data_hash(args['catalog']).to_ral
    catalog.environment = env.name.to_s
    catalog.environment_instance = env

    configurer = Puppet::Configurer.new
    configurer.run(catalog: catalog, report: report, pluginsync: false)
  end

  puts JSON.pretty_generate(report.to_data_hash)
  exit_code = report.exit_status != 1
ensure
  begin
    FileUtils.remove_dir(moduledir)
  rescue Errno::ENOTEMPTY => e
    STDERR.puts("Could not cleanup temporary directory: #{e}")
  end
end

exit exit_code
