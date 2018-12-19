# frozen_string_literal: true

require 'sinatra'
require 'bolt'
require 'bolt/error'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/pal'
require 'bolt/puppetdb'
require 'plan_executor/applicator'
require 'concurrent'
require 'json'
require 'json-schema'

module PlanExecutor
  class App < Sinatra::Base
    # This disables Sinatra's error page generation
    set :show_exceptions, false
    # Global var to capture output for testing
    result = nil

    helpers do
      def puppetdb_client
        return @puppetdb_client if @puppetdb_client
        @puppetdb_client = Bolt::PuppetDB::Client.new({})
      end
    end

    def initialize(modulepath, executor = nil)
      @schema = JSON.parse(File.read(File.join(__dir__, 'schemas', 'run_plan.json')))
      @worker = Concurrent::SingleThreadExecutor.new

      # Create a basic executor, leave concurrency up to Orchestrator.
      @executor = executor || Bolt::Executor.new(0, load_config: false)
      # Use an empty inventory until we figure out where this data comes from.
      @inventory = Bolt::Inventory.new(nil)
      # TODO: what should max compiles be set to for apply?
      @pal = Bolt::PAL.new(modulepath, nil)

      @applicator = PlanExecutor::Applicator.new(@inventory, @executor, nil)

      super(nil)
    end

    def validate_schema(schema, body)
      schema_error = JSON::Validator.fully_validate(schema, body)
      if schema_error.any?
        Bolt::Error.new("There was an error validating the request body.",
                        'boltserver/schema-error',
                        schema_error)
      end
    end

    get '/' do
      200
    end

    if ENV['RACK_ENV'] == 'dev'
      get '/admin/gc' do
        GC.start
        200
      end

      get '/admin/gc_stat' do
        [200, GC.stat.to_json]
      end
    end

    get '/500_error' do
      raise 'Unexpected error'
    end

    post '/plan/run' do
      content_type :json

      body = JSON.parse(request.body.read)
      error = validate_schema(@schema, body)
      return [400, error.to_json] unless error.nil?

      name = body['plan_name']
      # Errors if plan is not found
      @pal.get_plan_info(name)

      params = body['params']
      # This provides a wait function, which promise doesn't
      result = Concurrent::Future.execute(executor: @worker) do
        # Stores result in result for testing
        @pal.run_plan(name, params, @executor, @inventory, puppetdb_client, @applicator)
      end

      [200, { status: 'running' }.to_json]
    end

    # Provided for testing
    get '/plan/result' do
      result.wait_or_cancel(20)
      if result.fulfilled?
        return [200, result.value.to_json]
      elsif result.rejected?
        raise result.reason.to_s
      else
        return [200, result.state.to_s]
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
