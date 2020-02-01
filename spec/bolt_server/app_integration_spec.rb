# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/bolt_server'
require 'bolt/target'
require 'bolt_server/transport_app'
require 'bolt_server/config'
require 'rack/test'

describe "BoltServer::TransportApp", puppetserver: true do
  include BoltSpec::Conn
  include BoltSpec::BoltServer
  include Rack::Test::Methods

  def app
    config = BoltServer::Config.new(config_data)
    BoltServer::TransportApp.new(config)
  end

  context 'with ssh target', ssh: true do
    describe "run_task" do
      let(:path) { '/ssh/run_task' }

      it 'runs an echo task with a password' do
        body = build_task_request('sample::echo',
                                  conn_target('ssh', include_password: true),
                                  "message": "Hello!")

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result['result']['_output'].chomp).to match(/\w+ got passed the message: Hello!/)
      end

      it 'runs an echo task using a private key' do
        private_key = ENV['BOLT_SSH_KEY'] || Dir["spec/fixtures/keys/id_rsa"][0]
        private_key_content = File.read(private_key)
        target = conn_target('ssh', options: { 'private-key' => { 'key-data' => private_key_content } })
        body = build_task_request('sample::echo',
                                  target,
                                  "message": "Hello!")

        post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result['result']['_output'].chomp).to match(/\w+ got passed the message: Hello!/)
      end

      it 'runs a shareable task' do
        body = build_task_request('shareable',
                                  conn_target('ssh', include_password: true))

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        files = result['result']['_output'].split("\n").map(&:strip).sort
        expect(files.count).to eq(4)
        expect(files[0]).to match(%r{^174 .*/shareable/tasks/unknown_file.json$})
        expect(files[1]).to match(%r{^236 .*/shareable/tasks/list.sh})
        expect(files[2]).to match(%r{^398 .*/results/lib/puppet/functions/results/make_result.rb$})
        expect(files[3]).to match(%r{^43 .*/error/tasks/fail.sh$})
      end
    end

    describe "run_command" do
      let(:path) { '/ssh/run_command' }

      it 'runs an echo command' do
        body = build_command_request('echo hi',
                                     conn_target('ssh', include_password: true))

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result['result']["exit_code"]).to eq(0)
        expect(result['result']["stderr"]).to be_empty
        expect(result['result']["stdout"]).to eq("hi\n")
      end

      it 'fails reliably' do
        body = build_command_request('not-a-command',
                                     conn_target('ssh', include_password: true))

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'failure')
        expect(result['result']["exit_code"]).to eq(127)
        expect(result['result']["stderr"]).to match(/not-a-command/)
      end
    end

    describe "upload_file" do
      let(:path) { '/ssh/upload_file' }

      it 'copies files' do
        job_id = Time.now.usec
        body = build_upload_request(job_id, conn_target('ssh', include_password: true))
        destination = body['destination']

        begin
          post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
          expect(last_response).to be_ok
          expect(last_response.status).to eq(200)
          result = JSON.parse(last_response.body)
          expect(result).to include('status' => 'success')
          expect(result).to include('action' => 'upload')
          expect(result['result']['_output'])
            .to match(%r{Uploaded .*cache/#{job_id}' to 'localhost:#{destination}'})

          # Inspect results
          body = build_command_request("ls #{destination}/*",
                                       conn_target('ssh', include_password: true))

          post('/ssh/run_command', JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
          result = JSON.parse(last_response.body)
          expect(result['result']['stdout']).to match(/test-file.sh/)
          expect(result['result']['stdout']).to match(/sub-file.sh/)
        ensure
          # Cleanup after running
          body = build_command_request("rm -rf #{destination}",
                                       conn_target('ssh', include_password: true))
          post('/ssh/run_command', JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        end
      end

      it 'copies a single file' do
        job_id = Time.now.usec
        body = build_upload_request(job_id, conn_target('ssh', include_password: true))
        body['files'] = body['files'].select { |file_entry| file_entry['relative_path'] == 'test-file.sh' }
        body['destination'] = '/home/bolt/single_file_test.sh'
        destination = body['destination']

        begin
          post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
          expect(last_response).to be_ok
          expect(last_response.status).to eq(200)
          result = JSON.parse(last_response.body)
          expect(result).to include('status' => 'success')
          expect(result).to include('action' => 'upload')
          expect(result['result']['_output'])
            .to match(%r{Uploaded .*cache/#{job_id}/test-file.sh' to 'localhost:#{destination}'})

          # Inspect results
          body = build_command_request("ls #{destination}",
                                       conn_target('ssh', include_password: true))

          post('/ssh/run_command', JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
          result = JSON.parse(last_response.body)
          expect(result['result']['stdout']).to match(/single_file_test.sh/)
        ensure
          # Cleanup after running
          body = build_command_request("rm -rf #{destination}",
                                       conn_target('ssh', include_password: true))
          post('/ssh/run_command', JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        end
      end
    end

    describe "run_script" do
      let(:path) { '/ssh/run_script' }

      it 'copies and runs script' do
        body = build_script_request(conn_target('ssh', include_password: true))
        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result).to include('action' => 'script')
        expect(result['result']['stdout'])
          .to match(/hi!/)
          .and match(/test-file\.sh/)
          .and match(/--arg/)
      end

      it 'works without arguments' do
        body = build_script_request(conn_target('ssh', include_password: true))
        body.delete('arguments')
        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result).to include('action' => 'script')
        expect(result['result']['stdout'])
          .to match(/hi!/)
          .and match(/test-file\.sh/)
      end
    end

    describe "check_node_connections" do
      let(:path) { '/ssh/check_node_connections' }

      it 'checks connections on multiple targets, returning aggregated results' do
        targets = [
          conn_target('ssh', include_password: true)
        ]
        body = build_check_node_connections_request(targets)
        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        response_body = JSON.parse(last_response.body)
        expect(response_body['status']).to eq('success')
        expect(last_response.status).to eq(200)

        expect(response_body['result']).to be_a(Array)
        expect(response_body['result'].length).to eq(targets.length)
        expect(response_body['result'].all? { |r| r['status'] == 'success' })
      end
    end
  end
end
