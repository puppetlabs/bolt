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
    REQUEST_SCHEMAS = %w[action-run_task action-run_command action-upload_file transport-ssh transport-winrm].freeze

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
      return [], error unless error.nil?

      task = Bolt::Task::PuppetServer.new(body['task'], @file_cache)
      parameters = body['parameters'] || {}
      [@executor.run_task(target, task, parameters), nil]
    end

    def run_command(target, body)
      error = validate_schema(@schemas["action-run_command"], body)
      return [], error unless error.nil?

      command = body['command']
      [@executor.run_command(target, command), nil]
    end

    def upload_file(target, body)
      error = validate_schema(@schemas["action-upload_file"], body)
      return [], error unless error.nil?

      files = body['files']
      destination = body['destination']
      job_id = body['job_id']
      cache_dir = @file_cache.create_cache_dir(job_id.to_s)
      FileUtils.mkdir_p(cache_dir)
      files.each do |file|
        relative_path = file['relative_path']
        uri = file['uri']
        sha256 = file['sha256']
        kind = file['kind']
        path = File.join(cache_dir, relative_path)
        if kind == 'file'
          # The parent should already be created by `directory` entries,
          # but this is to be on the safe side.
          parent = File.dirname(path)
          FileUtils.mkdir_p(parent)
          @file_cache.download_file(path, sha256, uri)
        elsif kind == 'directory'
          # Create directory in cache so we can move files in.
          FileUtils.mkdir_p(path)
        else
          return [400, Bolt::Error.new("Invalid `kind` of '#{kind}' supplied. Must be `file` or `directory`.",
                                       'boltserver/schema-error').to_json]
        end
      end
      [@executor.upload_file(target, cache_dir, destination), nil]
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

    ACTIONS = %w[
      run_command
      run_task
      upload_file
    ].freeze

    def make_ssh_target(target_hash)
      defaults = {
        'host-key-check' => false
      }

      overrides = {
        'load-config' => false
      }

      opts = defaults.merge(target_hash.clone).merge(overrides)

      if opts['private-key-content']
        private_key_content = opts.delete('private-key-content')
        opts['private-key'] = { 'key-data' => private_key_content }
      end

      Bolt::Target.new(target_hash['hostname'], opts)
    end

    post '/ssh/:action' do
      not_found unless ACTIONS.include?(params[:action])

      content_type :json
      body = JSON.parse(request.body.read)

      error = validate_schema(@schemas["transport-ssh"], body)
      return [400, error.to_json] unless error.nil?

      targets = (body['targets'] || [body['target']]).map do |target|
        make_ssh_target(target)
      end

      resultset, error = method(params[:action]).call(targets, body)
      return [400, error.to_json] unless error.nil?

      json_results = resultset.map do |result|
        scrub_stack_trace(result.status_hash).to_json
      end

      if targets.length == 1
        [200, json_results.first]
      else
        [200, json_results]
      end
    end

    def make_winrm_target(target_hash)
      overrides = {
        'protocol' => 'winrm'
      }

      opts = target_hash.clone.merge(overrides)
      Bolt::Target.new(target_hash['hostname'], opts)
    end

    post '/winrm/:action' do
      not_found unless ACTIONS.include?(params[:action])

      content_type :json
      body = JSON.parse(request.body.read)

      error = validate_schema(@schemas["transport-winrm"], body)
      return [400, error.to_json] unless error.nil?

      targets = (body['targets'] || [body['target']]).map do |target|
        make_winrm_target(target)
      end

      resultset, error = method(params[:action]).call(targets, body)
      return [400, error.to_json] if error

      json_results = resultset.map do |result|
        scrub_stack_trace(result.status_hash).to_json
      end

      if targets.length == 1
        [200, json_results.first]
      else
        [200, json_results]
      end
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
