#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path(File.join(__dir__, '..', 'spec', 'lib')))

require 'bolt'
require 'bolt/inventory'
require 'bolt/config'
require 'bolt_spec/conn'
require 'bolt_spec/bolt_server'

require 'optparse'

class Client
  include BoltSpec::Conn
  include BoltSpec::BoltServer

  def initialize
    config = Bolt::Config.default
    plugins = Bolt::Plugin.setup(config, nil, nil, Bolt::Analytics::NoopClient.new)
    @inventory = Bolt::Inventory::Inventory.new(
      conn_inventory.merge(easy_config),
      config.transport,
      config.transports,
      plugins
    )
  end

  def easy_config
    {
      'ssh' => { 'host-key-check' => false }
    }
  end

  def target(target)
    @inventory.get_targets(target).first
  end

  def execute_request(uri, body)
    req = Net::HTTP::Post.new(uri)
    req.body = JSON.generate(body)
    req.add_field('CONTENT_TYPE', 'text/json')

    resp = make_client(uri).request(req)

    begin
      JSON.parse(resp.body)
    rescue StandardError
      puts "Could not parse: #{resp.body}"
    end
  end

  def run_task(task_name, target_name, params, base_uri: 'https://localhost:62658')
    target = target(target_name)
    body = build_task_request(task_name, target, params)

    uri = URI("#{base_uri}/#{target.protocol}/run_task")
    execute_request(uri, body)
  end

  def run_command(command, target_name, base_uri: 'https://localhost:62658')
    target = target(target_name)
    body = build_command_request(command, target)

    uri = URI("#{base_uri}/#{target.protocol}/apply")
    execute_request(uri, body)
  end

  def apply_catalog(apply_request, target_name, base_uri: 'https://localhost:62658')
    target = target(target_name)
    req = if File.exist?(apply_request)
            JSON.parse(apply_request)
          else
            catalog = cross_platform_catalog(target.name)
            apply_catalog_entry(catalog)
          end
    body = req.merge({ 'target' => target2request(target) })

    uri = URI("#{base_uri}/#{target.protocol}/apply_catalog")
    execute_request(uri, body)
  end
end

OptionParser.new do |opts|
  banner = "USAGE: bundle exec scripts/server_client.rb sample::echo ssh '{\"message\": \"hey\"}' -a run_task"
  opts.banner = banner

  object = ARGV[0]
  target = ARGV[1]
  client = Client.new

  unless object && target
    puts "Action object or target positional parameters are missing"
    puts banner
    exit 1
  end

  opts.on("-a", "--action ENUM", %i[run_task run_command apply], "Run action") do |action|
    case action
    when :run_task
      params = ARGV[2] || '{}'
      params = JSON.parse(params)
      puts JSON.pretty_generate(client.run_task(object, target, params))
    when :run_command
      puts JSON.pretty_generate(client.run_command(object, target))
    when :apply
      puts JSON.pretty_generate(client.apply_catalog(object, target))
    end
  end
end.parse!
