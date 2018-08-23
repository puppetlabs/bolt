# frozen_string_literal: true

require 'sinatra'
require 'bolt'
require 'bolt/task'
require 'json'

class TransportAPI < Sinatra::Base
  get '/' do
    200
  end

  post '/ssh/run_task' do
    content_type :json

    body = JSON.parse(request.body.read)
    keys = %w[user password port ssh-key-content connect-timeout run-as-command run-as
              tmpdir host-key-check known-hosts-content private-key-content sudo-password]
    opts = body['target'].select { |k, _| keys.include? k }

    if opts['private-key-content'] && opts['password']
      return [400, "Only include one of 'password' and 'private-key-content'"]
    end
    if opts['private-key-content']
      opts['private-key'] = { 'key-data' => opts['private-key-content'] }
      opts.delete('private-key-content')
    end

    target = [Bolt::Target.new(body['target']['hostname'], opts)]
    task = Bolt::Task.new(body['task'])
    parameters = body['parameters'] || {}

    executor = Bolt::Executor.new(load_config: false)

    # Since this will only be on one node we can just return the first result
    results = executor.run_task(target, task, parameters)
    [200, results.first.to_json]
  end

  post '/winrm/run_task' do
    content_type :json

    body = JSON.parse(request.body.read)
    keys = %w[user password port connect-timeout ssl ssl-verify tmpdir cacert extensions]
    opts = body['target'].select { |k, _| keys.include? k }
    opts['protocol'] = 'winrm'
    target = [Bolt::Target.new(body['target']['hostname'], opts)]
    task = Bolt::Task.new(body['task'])
    parameters = body['parameters'] || {}

    executor = Bolt::Executor.new(load_config: false)

    # Since this will only be on one node we can just return the first result
    results = executor.run_task(target, task, parameters)
    [200, results.first.to_json]
  end
end
