# frozen_string_literal: true

require 'sinatra'
require 'bolt'
require 'bolt/target'
require 'bolt/task'
require 'json'
require 'json-schema'

class TransportAPI < Sinatra::Base
  # This disables Sinatra's error page generation
  set :show_exceptions, false

  def initialize(app = nil)
    @schemas = {
      "ssh-run_task" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'ssh-run_task.json'))),
      "winrm-run_task" => JSON.parse(File.read(File.join(__dir__, 'schemas', 'winrm-run_task.json')))
    }
    shared_schema = JSON::Schema.new(JSON.parse(File.read(File.join(__dir__, 'schemas', 'task.json'))),
                                     Addressable::URI.parse("file:task"))
    JSON::Validator.add_schema(shared_schema)

    @executor = Bolt::Executor.new(0, load_config: false)

    super(app)
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

    # CODEREVIEW: the schema is additionalProperties false do we need this?
    keys = %w[user password port connect-timeout run-as-command run-as
              tmpdir host-key-check known-hosts-content private-key-content sudo-password
              tty]
    opts = body['target'].select { |k, _| keys.include? k }

    if opts['private-key-content']
      opts['private-key'] = { 'key-data' => opts['private-key-content'] }
      opts.delete('private-key-content')
    end

    target = [Bolt::Target.new(body['target']['hostname'], opts)]
    task = Bolt::Task.new(body['task'])
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

    keys = %w[user password port connect-timeout ssl ssl-verify tmpdir cacert extensions]
    opts = body['target'].select { |k, _| keys.include? k }
    opts['protocol'] = 'winrm'
    target = [Bolt::Target.new(body['target']['hostname'], opts)]
    task = Bolt::Task.new(body['task'])
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
