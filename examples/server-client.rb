#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'bolt'
require 'json'

puts "Starting bolt service..."
pid = Process.spawn('bolt-server')
sleep(2)

# Send HTTP requests
@uri = URI.parse("http://localhost:4567/ssh/run_task")
@http = Net::HTTP.new(@uri.host, @uri.port)

@header = { 'Content-Type': 'text/json' }

def make_request(req_body)
  json = JSON.generate(req_body)
  request = Net::HTTP::Post.new(@uri.request_uri, @header)
  request.body = json
  response = @http.request(request)
  puts "Responded with #{response.body}\n\n"
  if response.body['result']['_error']
    puts response.body['result']['_error']['details']['stack_trace']
  end
end

# First request
body = { 'task' => {},
         'target' => {},
         'parameters' => {} }
body['task']['name'] = "echo"
body['task']['metadata'] = {
  "description": "Echo a message",
  "parameters": { "message" => "Hello world!" }
}
file = File.open(File.join(File.dirname(__FILE__), "echo-task"))
body['task']['file'] = { 'filename': 'echo.rb',
                         'file_content': file.read }
body['target']['hostname'] = 'localhost'
body['target']['user'] = ENV['BOLT_USER']
body['target']['password'] = ENV['BOLT_PW']
body['target']['options'] =  { "host-key-check" => "false",
                               "insecure" => "true" }
body['parameters'] = { "message" => "Hello!" }
make_request(body)

# Second request
file = File.open(File.join(File.dirname(__FILE__), "package-task"))
body['task']['file'] = { 'filename': 'package',
                         'file_content': file.read }
body['task']['name'] = 'package::status'
body['parameters'] = { 'name' => 'cowsay',
                       'action' => "status",
                       'version' => "",
                       'provider' => 'apt' }
make_request(body)

puts "Stopping bolt service..."
Process.kill("HUP", pid)
