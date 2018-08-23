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
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
      result = JSON.parse(last_response.body)
      expect(result['status']).to eq('failure')
      expect(result['result']['_error']['msg']).to match(/Authentication failed for user/)
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
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
      result = JSON.parse(last_response.body)
      expect(result['status']).to eq('failure')
      expect(result['result']['_error']['msg']).to match(/Failed to connect to .* password is a required option/)
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
end
