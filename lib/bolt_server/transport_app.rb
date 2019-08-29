# frozen_string_literal: true

require 'sinatra'
require 'addressable/uri'
require 'bolt'
require 'bolt/error'
require 'bolt/target'
require 'bolt_server/file_cache'
require 'bolt/task/puppet_server'
require 'json'
require 'json-schema'

module BoltServer
  class TransportApp < Sinatra::Base
    # This disables Sinatra's error page generation
    set :show_exceptions, false

    # These partial schemas are reused to build multiple request schemas
    PARTIAL_SCHEMAS = %w[target-any target-ssh target-winrm task].freeze

    # These schemas combine shared schemas to describe client requests
    REQUEST_SCHEMAS = %w[action-run_task action-run_command transport-ssh transport-winrm].freeze

    def initialize(config)
      @config = config
      @schemas = Hash[REQUEST_SCHEMAS.map do |basename|
        [basename, JSON.parse(File.read(File.join(__dir__, ['schemas', "#{basename}.json"])))]
      end]

      PARTIAL_SCHEMAS.each do |basename|
        schema_content = JSON.parse(File.read(File.join(__dir__, ['schemas', 'partials', "#{basename}.json"])))
        shared_schema = JSON::Schema.new(schema_content, Addressable::URI.parse("partial:#{basename}"))
        JSON::Validator.add_schema(shared_schema)
      end

      @executor = Bolt::Executor.new(0)

      @file_cache = BoltServer::FileCache.new(@config).setup

      super(nil)
    end

    def scrub_stack_trace(result)
      if result.dig(:result, '_error', 'details', 'stack_trace')
        result[:result]['_error']['details'].reject! { |k| k == 'stack_trace' }
      end
      result
    end

    def validate_schema(schema, body)
      schema_error = JSON::Validator.fully_validate(schema, body)
      if schema_error.any?
        Bolt::Error.new("There was an error validating the request body.",
                        'boltserver/schema-error',
                        schema_error)
      end
    end

    def run_task(target, body)
      error = validate_schema(@schemas["action-run_task"], body)
      return [400, error.to_json] unless error.nil?

      task = Bolt::Task::PuppetServer.new(body['task'], @file_cache)
      parameters = body['parameters'] || {}
      @executor.run_task(target, task, parameters)
    end

    def run_command(target, body)
      error = validate_schema(@schemas["action-run_command"], body)
      return [400, error.to_json] unless error.nil?

      command = body['command']
      @executor.run_command(target, command)
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

    ACTIONS = %w[run_task run_command].freeze

    post '/ssh/:action' do
      not_found unless ACTIONS.include?(params[:action])

      content_type :json
      body = JSON.parse(request.body.read)

      error = validate_schema(@schemas["transport-ssh"], body)
      return [400, error.to_json] unless error.nil?

      defaults = { 'host-key-check' => false }
      opts = defaults.merge(body['target'])
      if opts['private-key-content']
        opts['private-key'] = { 'key-data' => opts['private-key-content'] }
        opts.delete('private-key-content')
      end
      opts['load-config'] = false
      target = [Bolt::Target.new(body['target']['hostname'], opts)]

      results = method(params[:action]).call(target, body)

      # Since this will only be on one node we can just return the first result
      result = scrub_stack_trace(results.first.status_hash)
      [200, result.to_json]
    end

    post '/winrm/:action' do
      not_found unless ACTIONS.include?(params[:action])

      content_type :json
      body = JSON.parse(request.body.read)

      error = validate_schema(@schemas["transport-winrm"], body)
      return [400, error.to_json] unless error.nil?

      opts = body['target'].clone.merge('protocol' => 'winrm')
      target = [Bolt::Target.new(body['target']['hostname'], opts)]

      results = method(params[:action]).call(target, body)

      # Since this will only be on one node we can just return the first result
      result = scrub_stack_trace(results.first.status_hash)
      [200, result.to_json]
    end

    error 404 do
      err = Bolt::Error.new("Could not find route #{request.path}",
                            'boltserver/not-found')
      [404, err.to_json]
    end

    error 500 do
      e = env['sinatra.error']
      err = Bolt::Error.new("500: Unknown error: #{e.message}",
                            'boltserver/server-error')
      [500, err.to_json]
    end
  end
end
