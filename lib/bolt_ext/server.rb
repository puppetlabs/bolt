# frozen_string_literal: true

require 'sinatra'
require 'bolt'
require 'bolt/task'
require 'json'

class TransportAPI < Sinatra::Base
  post '/ssh/run_task' do
    content_type :json

    body = JSON.parse(request.body.read)
    keys = %w[user password port ssh-key-content connect-timeout run-as-command
              run-as tmpdir host-key-check known-hosts-content sudo-password]
    opts = body['target'].select { |k, _| keys.include? k }
    target = [Bolt::Target.new(body['target']['hostname'], opts)]
    task = Bolt::Task.new(body['task'])
    parameters = body['parameters']

    executor = Bolt::Executor.new

    # Since this will only be on one node we can just set r to the result
    executor.run_task(target, task, parameters) do |event|
      if event[:type] == :node_result
        @r = event[:result].to_json
      end
    end

    [200, [@r]]
  end
end
