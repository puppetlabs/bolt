#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path(File.join(__dir__, '..', 'spec', 'lib')))

require 'bolt'
require 'bolt/inventory'
require 'bolt_spec/conn'
require 'bolt_spec/bolt_server'

task = ARGV[0]
target = ARGV[1]
params = ARGV[2] || '{}'

unless task && target
  puts(<<~MSG)
      Fetch task data from the dev puppetserver container and run a task through the local bolt-server
      USAGE: bundle exec scripts/server_client.rb sample::echo ssh '{"message": "hey"}'
    MSG
  exit 1
end

params = JSON.parse(params)

class Client
  include BoltSpec::Conn
  include BoltSpec::BoltServer

  def initialize
    @inventory = Bolt::Inventory.new(conn_inventory.merge(easy_config))
  end

  def easy_config
    {
      'ssh' => { 'host-key-check' => false }
    }
  end

  def target(target)
    @inventory.get_targets(target).first
  end

  def run_task(task_name, target_name, params, base_uri: 'https://localhost:62658')
    target = target(target_name)
    body = build_task_request(task_name, target, params)

    uri = URI("#{base_uri}/#{target.protocol}/run_task")
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
end

client = Client.new

puts JSON.pretty_generate(client.run_task(task, target, params))
