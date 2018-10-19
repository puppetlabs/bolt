# frozen_string_literal: true

require 'sinatra'
require 'bolt'
require 'bolt/target'
require 'bolt/task/puppet_server'
require 'bolt_server/file_cache'
require 'json'
require 'json-schema'

module BoltServer
  class TransportApp < Sinatra::Base
    # This disables Sinatra's error page generation
    set :show_exceptions, false

    def initialize(config)
      @config = config
      @schemas = {
        "ssh-run_task" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'ssh-run_task.json'))),
        "winrm-run_task" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'winrm-run_task.json')))
      }
      shared_schema = JSON::Schema.new(JSON.parse(File.read(File.join(__dir__, 'schemas', 'task.json'))),
                                       Addressable::URI.parse("file:task"))
      JSON::Validator.add_schema(shared_schema)

      @executor = Bolt::Executor.new(0, load_config: false)

      @file_cache = BoltServer::FileCache.new(@config).setup

      super(nil)
    end

    get '/' do
      200
    end

    if ENV['RACK_ENV'] == 'dev'
      get '/admin/gc' do
        GC.start
        200
      end
    end

    get '/admin/gc_stat' do
      [200, GC.stat.to_json]
    end

    get '/500_error' do
      raise 'Unexpected error'
    end

    post '/ssh/run_task' do
      content_type :json

      body = JSON.parse(request.body.read)
      schema_error = JSON::Validator.fully_validate(@schemas["ssh-run_task"], body)
      return [400, schema_error.join] if schema_error.any?

      opts = body['target']
      if opts['private-key-content']
        opts['private-key'] = { 'key-data' => opts['private-key-content'] }
        opts.delete('private-key-content')
      end

      target = [Bolt::Target.new(body['target']['hostname'], opts)]

      task = Bolt::Task::PuppetServer.new(body['task'], @file_cache)

      parameters = body['parameters'] || {}

      # Since this will only be on one node we can just return the first result
      results = @executor.run_task(target, task, parameters)
      [200, results.first.to_json]
    end

    post '/winrm/run_task' do
      content_type :json

      body = JSON.parse(request.body.read)
      schema_error = JSON::Validator.fully_validate(@schemas["winrm-run_task"], body)
      return [400, schema_error.join] if schema_error.any?

      opts = body['target'].merge('protocol' => 'winrm')

      target = [Bolt::Target.new(body['target']['hostname'], opts)]

      task = Bolt::Task::PuppetServer.new(body['task'], @file_cache)

      parameters = body['parameters'] || {}

      # Since this will only be on one node we can just return the first result
      results = @executor.run_task(target, task, parameters)
      [200, results.first.to_json]
    end

    error 404 do
      [404, "Could not find route #{request.path}"]
    end

    error 500 do
      e = env['sinatra.error']
      [500, "500: Unknown error: #{e.message}"]
    end
  end
end
