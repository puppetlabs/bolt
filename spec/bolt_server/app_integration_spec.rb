# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/bolt_server'
require 'bolt/target'
require 'bolt_server/transport_app'
require 'bolt_server/config'
require 'rack/test'
require 'fileutils'

describe "BoltServer::TransportApp", puppetserver: true do
  include BoltSpec::Conn
  include BoltSpec::BoltServer
  include Rack::Test::Methods

  def app
    config = BoltServer::Config.new(config_data)
    BoltServer::TransportApp.new(config)
  end

  before(:all) do
    wait_until_available(timeout: 30, interval: 1)
  end

  context 'with ssh target', ssh: true do
    describe "run_task" do
      let(:path) { '/ssh/run_task' }

      it 'runs an echo task with a password' do
        body = build_task_request('sample::echo',
                                  conn_target('ssh', include_password: true),
                                  message: "Hello!")

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result['value']['_output'].chomp).to match(/\w+ got passed the message: Hello!/)
      end

      it 'runs an echo task using a private key' do
        private_key = ENV['BOLT_SSH_KEY'] || Dir["spec/fixtures/keys/id_rsa"][0]
        private_key_content = File.read(private_key)
        target = conn_target('ssh', options: { 'private-key' => { 'key-data' => private_key_content } })
        body = build_task_request('sample::echo',
                                  target,
                                  message: "Hello!")

        post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        expect(result['value']['_output'].chomp).to match(/\w+ got passed the message: Hello!/)
      end

      it 'runs a shareable task' do
        body = build_task_request('shareable',
                                  conn_target('ssh', include_password: true))

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'success')
        files = result['value']['_output'].split("\n").map(&:strip).sort
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
        expect(result['value']["exit_code"]).to eq(0)
        expect(result['value']["stderr"]).to be_empty
        expect(result['value']["stdout"]).to eq("hi\n")
      end

      it 'fails reliably' do
        body = build_command_request('not-a-command',
                                     conn_target('ssh', include_password: true))

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result).to include('status' => 'failure')
        expect(result['value']["exit_code"]).to eq(127)
        expect(result['value']["stderr"]).to match(/not-a-command/)
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
          expect(result['value']['_output'])
            .to match(%r{Uploaded .*cache/#{job_id}' to 'localhost:#{destination}'})

          # Inspect results
          body = build_command_request("ls #{destination}/*",
                                       conn_target('ssh', include_password: true))

          post('/ssh/run_command', JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
          result = JSON.parse(last_response.body)
          expect(result['value']['stdout']).to match(/test-file.sh/)
          expect(result['value']['stdout']).to match(/sub-file.sh/)
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
          expect(result['value']['_output'])
            .to match(%r{Uploaded .*cache/#{job_id}/test-file.sh' to 'localhost:#{destination}'})

          # Inspect results
          body = build_command_request("ls #{destination}",
                                       conn_target('ssh', include_password: true))

          post('/ssh/run_command', JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
          result = JSON.parse(last_response.body)
          expect(result['value']['stdout']).to match(/single_file_test.sh/)
        ensure
          # Cleanup after running
          body = build_command_request("rm -rf #{destination}",
                                       conn_target('ssh', include_password: true))
          post('/ssh/run_command', JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        end
      end
    end

    describe 'apply_prep' do
      let(:path) { "/ssh/apply_prep" }

      it 'apply_prep runs install task configured in plugin_hooks and gathers custom facts' do
        # Target a spec container that already has an agent on it
        inventory = Bolt::Inventory.empty
        puppet_6_agent_container = inventory.get_target(conn_uri('ssh', include_password: true, override_port: 20024))
        target = {
          hostname: puppet_6_agent_container.host,
          user: puppet_6_agent_container.user,
          password: puppet_6_agent_container.password,
          port: puppet_6_agent_container.port,
          plugin_hooks: { 'puppet_library' => { 'plugin' => 'task', 'task' => 'fake_puppet_agent::install',
                                                'parameters' => {} } }
        }
        body = {
          versioned_project: 'bolt_server_test_project',
          target: target
        }
        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result['status']).to eq('success')
        expect(result['value'].keys).to include('os')
      end

      it 'apply_prep fails when install task fails' do
        # Target a spec container that already has an agent on it
        inventory = Bolt::Inventory.empty
        puppet_6_agent_container = inventory.get_target(conn_uri('ssh', include_password: true, override_port: 20024))
        target = {
          hostname: puppet_6_agent_container.host,
          user: puppet_6_agent_container.user,
          password: puppet_6_agent_container.password,
          port: puppet_6_agent_container.port,
          plugin_hooks: { 'puppet_library' => { 'plugin' => 'task', 'task' => 'fake_puppet_agent::install',
                                                'parameters' => { 'fail' => true } } }
        }
        body = {
          versioned_project: 'bolt_server_test_project',
          target: target
        }
        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result['status']).to eq('failure')
        expect(result['object']).to eq('fake_puppet_agent::install')
      end

      it 'apply_prep fails when target does not define suitable puppet_library plugin_hook' do
        # Target a spec container that already has an agent on it
        inventory = Bolt::Inventory.empty
        puppet_6_agent_container = inventory.get_target(conn_uri('ssh', include_password: true, override_port: 20024))
        target = {
          hostname: puppet_6_agent_container.host,
          user: puppet_6_agent_container.user,
          password: puppet_6_agent_container.password,
          port: puppet_6_agent_container.port
        }
        body = {
          versioned_project: 'bolt_server_test_project',
          target: target
        }
        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response.status).to eq(400)
        result = JSON.parse(last_response.body)
        expect(result['kind']).to eq('bolt-server/request-error')
        expect(result['msg']).to eq("Target must have 'task' plugin hook")
      end
    end

    describe "apply" do
      def cross_platform_catalog(certname)
        {
          "catalog" => {
            "tags" => [
              "settings"
            ],
            "name" => certname,
            "version" => 1581636379,
            "code_id" => nil,
            "catalog_uuid" => "5a4372c6-253f-46df-be99-3c40c9922423",
            "catalog_format" => 1,
            "environment" => 'bolt_catalog',
            "resources" => [
              {
                "type" => "Stage",
                "title" => "main",
                "tags" => %w[
                  stage
                  class
                ],
                "exported" => false,
                "parameters" => {
                  "name" => "main"
                }
              },
              {
                "type" => "Class",
                "title" => "Settings",
                "tags" => %w[
                  class
                  settings
                ],
                "exported" => false
              },
              {
                "type" => "Class",
                "title" => "main",
                "tags" => [
                  "class"
                ],
                "exported" => false,
                "parameters" => {
                  "name" => "main"
                }
              },
              {
                "type" => "Notify",
                "title" => "hello world",
                "tags" => %w[
                  notify
                  class
                ],
                "line" => 1,
                "exported" => false
              }
            ],
            "edges" => [
              {
                "source" => "Stage[main]",
                "target" => "Class[Settings]"
              },
              {
                "source" => "Stage[main]",
                "target" => "Class[main]"
              },
              {
                "source" => "Class[main]",
                "target" => "Notify[hello world]"
              }
            ],
            "classes" => [
              "settings"
            ]
          }
        }
      end

      it 'applies a catalog' do
        # Target a spec container that already has an agent on it
        path = 'ssh/apply'
        inventory = Bolt::Inventory.empty
        puppet_6_agent_container = inventory.get_target(conn_uri('ssh', include_password: true, override_port: 20024))
        target = {
          hostname: puppet_6_agent_container.host,
          user: puppet_6_agent_container.user,
          password: puppet_6_agent_container.password,
          port: puppet_6_agent_container.port,
          plugin_hooks: { 'puppet_library' => { 'plugin' => 'task', 'task' => 'fake_puppet_agent::install',
                                                'parameters' => {} } }
        }
        body = {
          versioned_project: 'bolt_server_test_project',
          target: target,
          parameters: {
            catalog: cross_platform_catalog(target[:hostname])['catalog'],
            apply_settings: {}
          }
        }
        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result['status']).to eq('success')
        expect(result['value']['resource_statuses'].keys).to include('Notify[hello world]')
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
        expect(result['value']['stdout'])
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
        expect(result['value']['stdout'])
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
