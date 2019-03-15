# frozen_string_literal: true

require 'sinatra'
require 'bolt'
require 'bolt/error'
require 'bolt/inventory'
require 'bolt/pal'
require 'bolt/puppetdb'
require 'bolt/version'
require 'plan_executor/applicator'
require 'plan_executor/executor'
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

    def initialize(config)
      # lazy-load expensive gem code
      require 'concurrent'

      @http_client = create_http(config)

      # Use an empty inventory until we figure out where this data comes from.
      @inventory = Bolt::Inventory.new(nil)

      # PAL is not threadsafe. Part of the work of making the plan executor
      # functional will be making changes to Puppet that remove the need for
      # global Puppet state.
      # https://github.com/puppetlabs/bolt/blob/master/lib/bolt/pal.rb#L166
      @pal = Bolt::PAL.new(config['modulepath'], nil)

      @schema = JSON.parse(File.read(File.join(__dir__, 'schemas', 'run_plan.json')))
      @worker = Concurrent::SingleThreadExecutor.new
      @modulepath = config['modulepath']

      super(nil)
    end

    def create_http(config)
      base_url = config['orchestrator-url'].chomp('/') + '/orchestrator/v1/'
      agent_name = "Bolt/#{Bolt::VERSION}"
      http = JSONClient.new(base_url: base_url, agent_name: agent_name)
      http.ssl_config.set_client_cert_file(config['ssl-cert'], config['ssl-key'])
      http.ssl_config.add_trust_ca(config['ssl-ca-cert'])
      http
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

      executor = PlanExecutor::Executor.new(body['job_id'], @http_client)
      applicator = PlanExecutor::Applicator.new(@inventory, executor, nil)
      params = body['params']
      # This provides a wait function, which promise doesn't
      result = Concurrent::Future.execute(executor: @worker) do
        pal_result = @pal.run_plan(name, params, executor, @inventory, puppetdb_client, applicator)
        executor.finish_plan(pal_result)
        pal_result
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
