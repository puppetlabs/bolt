# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/bolt_server'
require 'bolt_spec/conn'
require 'bolt_spec/file_cache'
require 'bolt_server/config'
require 'bolt_server/transport_app'
require 'json'
require 'rack/test'

describe "BoltServer::TransportApp" do
  include BoltSpec::BoltServer
  include BoltSpec::Conn
  include BoltSpec::FileCache
  include Rack::Test::Methods

  def app
    moduledir = File.join(__dir__, '..', 'fixtures', 'modules')
    mock_file_cache(moduledir)
    config = BoltServer::Config.new(default_config)
    BoltServer::TransportApp.new(config)
  end

  def file_data(file)
    { 'uri' => {
      'path' => "/tasks/#{File.basename(file)}",
      'params' => { 'param' => 'val' }
    },
      'filename' => File.basename(file),
      'sha256' => Digest::SHA256.file(file),
      'size' => File.size(file) }
  end

  it 'responds ok' do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.status).to eq(200)
  end

  context 'when raising errors' do
    it 'returns non-html 404 when the endpoint is not found' do
      post '/ssh/run_tasksss', JSON.generate({}), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(404)
      result = JSON.parse(last_response.body)
      expect(result['msg']).to eq("Could not find route /ssh/run_tasksss")
      expect(result['kind']).to eq("boltserver/not-found")
    end

    it 'returns non-html 500 when the request times out' do
      get '/500_error'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(500)
      result = JSON.parse(last_response.body)
      expect(result['msg']).to eq('500: Unknown error: Unexpected error')
      expect(result['kind']).to eq('boltserver/server-error')
    end
  end

  describe 'transport routes' do
    let(:action) { 'run_task' }
    let(:result) { double(Bolt::Result, status_hash: { status: 'test_status' }) }

    before(:each) do
      allow_any_instance_of(BoltServer::TransportApp)
        .to receive(action.to_sym).and_return(
          Bolt::ResultSet.new([result])
        )
    end

    describe '/ssh/*' do
      let(:path) { "/ssh/#{action}" }
      let(:target) { conn_info('ssh') }

      it 'returns a non-html 404 if the action does not exist' do
        post('/ssh/not_an_action', JSON.generate({}), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).not_to be_ok
        expect(last_response.status).to eq(404)

        result = JSON.parse(last_response.body)
        expect(result['kind']).to eq('boltserver/not-found')
      end

      it 'errors if both password and private-key-content are present' do
        body = { target: {
          password: 'password',
          'private-key-content': 'private-key-content'
        } }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).not_to be_ok
        expect(last_response.status).to eq(400)

        result = JSON.parse(last_response.body)
        regex = %r{The property '#/target' of type object matched more than one of the required schemas}
        expect(result['details'].join).to match(regex)
      end

      it 'fails if no authorization is present' do
        body = { target: {
          hostname: target[:host],
          user: target[:user],
          port: target[:port],
          'host-key-check': false
        } }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).not_to be_ok
        expect(last_response.status).to eq(400)

        result = last_response.body
        expect(result).to match(%r{The property '#/target' of type object did not match any of the required schemas})
      end

      it 'performs the action when using a password and scrubs any stack traces' do
        body = { 'target': {
          'hostname': target[:host],
          'user': target[:user],
          'password': target[:password],
          'port': target[:port],
          'host-key-check': false
        } }

        expect_any_instance_of(BoltServer::TransportApp)
          .to receive(:scrub_stack_trace).with(result.status_hash).and_return({})

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end

      it 'performs an action when using a private key and scrubs any stack traces' do
        private_key = ENV['BOLT_SSH_KEY'] || Dir["spec/fixtures/keys/id_rsa"][0]
        private_key_content = File.read(private_key)

        body = { 'target': {
          'hostname': target[:host],
          'user': target[:user],
          'private-key-content': private_key_content,
          'port': target[:port],
          'host-key-check': false
        } }

        expect_any_instance_of(BoltServer::TransportApp)
          .to receive(:scrub_stack_trace).with(result.status_hash).and_return({})

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end
    end

    describe '/winrm/*' do
      let(:path) { "/winrm/#{action}" }
      let(:target) { conn_info('winrm') }

      it 'returns a non-html 404 if the action does not exist' do
        post('/winrm/not_an_action', JSON.generate({}), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).not_to be_ok
        expect(last_response.status).to eq(404)

        result = JSON.parse(last_response.body)
        expect(result['kind']).to eq('boltserver/not-found')
      end

      it 'fails if no authorization is present' do
        body = { target: {
          hostname: target[:host],
          user: target[:user],
          port: target[:port]
        } }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).not_to be_ok
        expect(last_response.status).to eq(400)

        result = last_response.body
        expect(result).to match(%r{The property '#/target' did not contain a required property of 'password'})
      end

      it 'fails if either port or connect-timeout is a string' do
        body = { target: {
          hostname: target[:host],
          uaser: target[:user],
          password: target[:password],
          port: 'port',
          'connect-timeout': 'timeout'
        } }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).not_to be_ok
        expect(last_response.status).to eq(400)

        result = last_response.body
        [
          %r{The property '#/target/port' of type string did not match the following type: integer},
          %r{The property '#/target/connect-timeout' of type string did not match the following type: integer}
        ].each do |re|
          expect(result).to match(re)
        end
      end

      it 'performs the action and scrubs any stack traces from the result' do
        body = { target: {
          hostname: target[:host],
          user: target[:user],
          password: target[:password],
          port: target[:port]
        } }

        expect_any_instance_of(BoltServer::TransportApp)
          .to receive(:scrub_stack_trace).with(result.status_hash).and_return({})

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe 'action endpoint' do
    # Helper to set the transport on a body hash, and then post
    # to an action endpoint (/ssh/<action> or /winrm/<action>)
    def post_over_transport(transport, action, body_defaults = {})
      path = "/#{transport}/#{action}"

      target = conn_info(transport)
      body = body_defaults.merge(target: {
                                   hostname: target[:host],
                                   user: target[:user],
                                   password: target[:password],
                                   port: target[:port]
                                 })
      body[:target]['host-key-check'] = false if transport == 'ssh'

      post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
    end

    describe 'run_task' do
      it 'runs a simple echo task over SSH', :ssh do
        example_task = {
          task: { name: 'sample::echo',
                  metadata: {
                    description: 'Echo a message',
                    parameters: { message: 'Default message' }
                  },
                  files: [{ filename: "echo.sh", sha256: "foo",
                            uri: { path: 'foo', params: { environment: 'foo' } } }] },
          parameters: { message: "Hello!" }
        }

        post_over_transport('ssh', 'run_task', example_task)

        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)

        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result['result']['_output']).to match(/got passed the message: Hello!/)
      end

      it "runs a simple echo task over WinRM", :winrm do
        example_task = {
          task: {
            name: 'sample::wininput',
            metadata: {
              description: 'Echo a message',
              input_method: 'stdin'
            },
            files: [{ filename: 'wininput.ps1', sha256: 'foo',
                      uri: { path: 'foo', params: { environment: 'foo' } } }]
          },
          parameters: { input: 'Hello!' }
        }

        post_over_transport('winrm', 'run_task', example_task)

        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)

        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result['result']['_output']).to match(/INPUT.*Hello!/)
      end
    end
  end
end
