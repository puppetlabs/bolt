# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_ext/server'
require 'json'
require 'rack/test'

describe "TransportAPI" do
  include BoltSpec::Conn
  include Rack::Test::Methods

  def app
    TransportAPI
  end

  it 'responds ok' do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.status).to eq(200)
  end

  context 'with ssh target', ssh: true do
    let(:target) { conn_info('ssh') }
    let(:path) { '/ssh/run_task' }
    let(:echo_task) {
      {
        'name': 'echo',
        'metadata': {
          'description': 'Echo a message',
          'parameters': { 'message': 'Default message' }
        },
        'file': {
          'file_content': Base64.encode64("#!/usr/bin/env bash\necho $PT_message"),
          'filename': "echo.sh"
        }
      }
    }

    it 'errors if both password and private-key-content are present' do
      body = {
        'task': echo_task,
        'target': {
          'password': 'foo',
          'private-key-content': 'content'
        },
        'parameters': { "message": "Hello!" }
      }

      post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(400)
      result = last_response.body
      expect(result).to match(%r{The property '#/target' of type object matched more than one of the required schemas})
    end

    it 'fails if no authorization is present' do
      body = {
        'task': echo_task,
        'target': {
          'hostname': target[:host],
          'user': target[:user],
          'port': target[:port],
          'host-key-check': false
        },
        'parameters': { "message": "Hello!" }
      }

      post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(400)
      result = last_response.body
      expect(result).to match(%r{The property '#/target' of type object did not match any of the required schemas})
    end

    it 'runs an echo task' do
      body = {
        'task': echo_task,
        'target': {
          'hostname': target[:host],
          'user': target[:user],
          'password': target[:password],
          'port': target[:port],
          'host-key-check': false
        },
        'parameters': { "message": "Hello!" }
      }

      post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
      result = JSON.parse(last_response.body)
      expect(result['status']).to eq('success')
      expect(result['result']['_output'].chomp).to eq('Hello!')
    end

    it 'runs an echo task using a private key' do
      private_key = ENV['BOLT_SSH_KEY'] || Dir["spec/fixtures/keys/id_rsa"][0]
      private_key_content = File.read(private_key)

      body = {
        'task': echo_task,
        'target': {
          'hostname': target[:host],
          'user': target[:user],
          'private-key-content': private_key_content,
          'port': target[:port],
          'host-key-check': false
        },
        'parameters': { "message": "Hello!" }
      }

      post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
      result = JSON.parse(last_response.body)
      expect(result['status']).to eq('success')
      expect(result['result']['_output'].chomp).to eq('Hello!')
    end
  end

  context 'with winrm target', winrm: true do
    let(:target) { conn_info('winrm') }
    let(:path) { '/winrm/run_task' }
    let(:echo_task) {
      {
        'name': 'echo',
        'metadata': {
          'description': 'Echo a message',
          'parameters': { 'message': 'Default message' }
        },
        'file': {
          'file_content': Base64.encode64("param ($message)\nWrite-Output \"$message\""),
          'filename': "echo.ps1"
        }
      }
    }

    it 'fails if no authorization is present' do
      body = {
        'task': echo_task,
        'target': {
          'hostname': target[:host],
          'user': target[:user],
          'port': target[:port]
        },
        'parameters': { "message": "Hello!" }
      }

      post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(400)
      result = last_response.body
      expect(result).to match(%r{The property '#/target' did not contain a required property of 'password'})
    end

    it 'fails if either port or connect-timeout is a string' do
      body = {
        'task': echo_task,
        'target': {
          'hostname': target[:host],
          'user': target[:user],
          'password': target[:password],
          'port': "port",
          'connect-timeout': "timeout"
        },
        'parameters': { "message": "Hello!" }
      }

      post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(400)
      result = last_response.body

      expect(result).to match(%r{The property '#/target/port' of type string did not match the following type: integer})
      expect(result)
        .to match(%r{The property '#/target/connect-timeout' of type string did not match the following type: integer})
    end

    it 'runs an echo task' do
      body = {
        'task': echo_task,
        'target': {
          'hostname': target[:host],
          'user': target[:user],
          'password': target[:password],
          'port': target[:port]
        },
        'parameters': { "message": "Hello!" }
      }

      post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
      result = JSON.parse(last_response.body)
      expect(result['status']).to eq('success')
      expect(result['result']['_output'].chomp).to eq('Hello!')
    end
  end

  context 'when raising errors' do
    let(:target) { conn_info('ssh') }
    let(:echo_task) {
      {
        'name': 'echo',
        'metadata': {
          'description': 'Echo a message',
          'parameters': { 'message': 'Default message' }
        },
        'file': {
          'file_content': Base64.encode64("#!/usr/bin/env bash\necho $PT_message"),
          'filename': "echo.sh"
        }
      }
    }

    it 'returns non-html 404 when the endpoint is not found' do
      body = {
        'task': echo_task,
        'target': {
          'hostname': target[:host],
          'user': target[:user],
          'password': target[:password],
          'port': target[:port],
          'host-key-check': false
        },
        'parameters': { "message": "Hello!" }
      }

      post '/ssh/run_tasksss', JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(404)
      expect(last_response.body).to eq("Could not find route /ssh/run_tasksss")
    end

    it 'returns non-html 500 when the request times out' do
      get '/500_error'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(500)
      expect(last_response.body).to eq('500: Unknown error: Unexpected error')
    end
  end
end
