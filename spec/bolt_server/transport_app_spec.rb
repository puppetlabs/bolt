# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/bolt_server'
require 'bolt_spec/conn'
require 'bolt_spec/file_cache'
require 'bolt_spec/files'
require 'bolt_server/config'
require 'bolt_server/transport_app'
require 'json'
require 'rack/test'
require 'puppet/environments'
require 'digest'
require 'pathname'

describe "BoltServer::TransportApp" do
  include BoltSpec::BoltServer
  include BoltSpec::Conn
  include BoltSpec::FileCache
  include BoltSpec::Files
  include Rack::Test::Methods

  let(:basedir) { fixtures_path('bolt_server') }
  let(:environment_dir) { File.join(basedir, 'environments', 'production') }

  def app
    moduledir = fixtures_path('modules')
    mock_file_cache(moduledir)
    config = BoltServer::Config.new({ 'environments-codedir' => basedir })
    BoltServer::TransportApp.new(config)
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
    def mock_plan_info(full_name)
      module_name, _plan_name = full_name.split('::', 2)
      {
        'name' => full_name,
        'description' => 'foo',
        'parameters' => {},
        'module' => "/opt/puppetlabs/puppet/modules/#{module_name}"
      }
    end
    let(:action) { 'run_task' }
    let(:result) { double(Bolt::Result, to_data: { status: 'test_status' }, ok?: true) }

    before(:each) do
      allow_any_instance_of(BoltServer::TransportApp)
        .to receive(action.to_sym).and_return(
          Bolt::ResultSet.new([result])
        )
    end

    describe '/plans/:module_name/:plan_name' do
      context 'with module_name::plan_name' do
        let(:path) { '/plans/bolt_server_test/simple_plan?environment=production' }
        let(:expected_response) {
          {
            'name' => 'bolt_server_test::simple_plan',
            'description' => 'Simple plan testing',
            'parameters' => { 'foo' => { 'sensitive' => false, 'type' => 'String' } },
            'private' => false,
            'summary' => nil,
            'docstring' => 'Simple plan testing'
          }
        }
        it '/plans/:module_name/:plan_name handles module::plan_name' do
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with module_name' do
        let(:init_plan) { '/plans/bolt_server_test/init?environment=production' }
        let(:expected_response) {
          {
            'name' => 'bolt_server_test',
            'description' => 'Init plan testing',
            'parameters' => { 'bar' => { 'sensitive' => false, 'type' => 'String' } },
            'private' => false,
            'summary' => nil,
            'docstring' => 'Init plan testing'
          }
        }
        it '/plans/:module_name/:plan_name handles plan name = module name (init.pp) plan' do
          get(init_plan)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end
      context 'with non-existent plan' do
        let(:path) { '/plans/foo/bar?environment=production' }
        it 'returns 404 if an unknown plan error is thrown' do
          get(path)
          expect(last_response.status).to eq(404)
          err = JSON.parse(last_response.body)
          expect(err['kind']).to eq('bolt-server/request-error')
          expect(err['msg']).to eq("Could not find a plan named 'foo::bar'")
        end
      end
    end

    describe '/plans' do
      describe 'when metadata=false' do
        context 'with a real environment' do
          let(:path) { "/plans?environment=production" }
          it 'returns just the list of plan names when metadata=false' do
            get(path)
            metadata = JSON.parse(last_response.body)
            expect(metadata).to include({ 'name' => 'bolt_server_test' }, { 'name' => 'bolt_server_test::simple_plan' })
          end
        end

        context 'with a non-existent environment' do
          let(:path) { "/plans?environment=not_an_env" }
          it 'returns 400 if an environment not found error is thrown' do
            get(path)
            expect(last_response.status).to eq(400)
          end
        end

        context 'with a non existent environment' do
          let(:path) { "/plans" }
          it 'returns 400 if an environment query parameter not supplied' do
            get(path)
            expect(last_response.status).to eq(400)
            resp = JSON.parse(last_response.body)
            expect(resp['kind']).to eq('bolt-server/request-error')
            expect(resp['msg']).to eq("'environment' is a required argument")
          end
        end
      end

      describe 'when metadata=true' do
        let(:path) { '/plans?environment=production&metadata=true' }
        let(:expected_response) {
          {
            'bolt_server_test' => {
              'name' => 'bolt_server_test',
              'description' => 'Init plan testing',
              'parameters' => { 'bar' => { 'sensitive' => false, 'type' => 'String' } },
              'private' => false,
              'summary' => nil,
              'docstring' => 'Init plan testing'
            }
          }
        }
        it 'returns all metadata for each plan when metadata=true' do
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to include(expected_response)
        end
      end
    end

    describe '/tasks' do
      context 'with a non existent environment' do
        let(:path) { "/tasks?environment=production" }
        it 'returns just the list of task names' do
          get(path)
          metadata = JSON.parse(last_response.body)
          expect(metadata).to include({ 'name' => 'bolt_server_test' }, { 'name' => 'bolt_server_test::simple_task' })
        end
      end

      context 'with a non existent environment' do
        let(:path) { "/tasks?environment=not_a_real_env" }
        it 'returns 400 if an environment not found error is thrown' do
          get(path)
          expect(last_response.status).to eq(400)
        end
      end

      context 'with a non existent environment' do
        let(:path) { "/tasks" }
        it 'returns 400 if an environment query parameter not supplied' do
          get(path)
          expect(last_response.status).to eq(400)
          resp = JSON.parse(last_response.body)
          expect(resp['kind']).to eq('bolt-server/request-error')
          expect(resp['msg']).to eq("'environment' is a required argument")
        end
      end
    end

    describe '/tasks/:module_name/:task_name' do
      context 'with module_name::task_name' do
        let(:path) { '/tasks/bolt_server_test/simple_task?environment=production' }
        let(:expected_response) {
          {
            "metadata" => { "description" => "Environment task testing simple" },
            "name" => "bolt_server_test::simple_task",
            "files" => [
              {
                "filename" => "simple_task.sh",
                "sha256" => Digest::SHA256.hexdigest(
                  File.read(
                    File.join(environment_dir, 'modules', 'bolt_server_test', 'tasks', 'simple_task.sh')
                  )
                ),
                "size_bytes" => File.size(
                  File.join(environment_dir, 'modules', 'bolt_server_test', 'tasks', 'simple_task.sh')
                ),
                "uri" => {
                  "path" => "/puppet/v3/file_content/tasks/bolt_server_test/simple_task.sh",
                  "params" => { "environment" => "production" }
                }
              }
            ]
          }
        }
        it '/tasks/:module_name/:task_name handles module::task_name' do
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with module_name' do
        let(:path) { '/tasks/bolt_server_test/init?environment=production' }
        let(:expected_response) {
          {
            "metadata" => { "description" => "Environment task testing" },
            "name" => "bolt_server_test",
            "files" => [
              {
                "filename" => "init.sh",
                "sha256" => Digest::SHA256.hexdigest(
                  File.read(
                    File.join(environment_dir, 'modules', 'bolt_server_test', 'tasks', 'init.sh')
                  )
                ),
                "size_bytes" => File.size(
                  File.join(environment_dir, 'modules', 'bolt_server_test', 'tasks', 'init.sh')
                ),
                "uri" => {
                  "path" => "/puppet/v3/file_content/tasks/bolt_server_test/init.sh",
                  "params" => { "environment" => "production" }
                }
              }
            ]
          }
        }

        it '/tasks/:module_name/:task_name handles task name = module name (init.rb) task' do
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with non-existent task' do
        let(:path) { "/tasks/foo/bar?environment=production" }
        it 'returns 404 if an unknown task error is thrown' do
          get(path)
          expect(last_response.status).to eq(404)
          err = JSON.parse(last_response.body)
          expect(err['kind']).to eq('bolt-server/request-error')
          expect(err['msg']).to eq("Could not find a task named 'foo::bar'")
        end
      end
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
          port: target[:port]
        } }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).not_to be_ok
        expect(last_response.status).to eq(400)

        result = last_response.body
        expect(result).to match(%r{The property '#/target' of type object did not match any of the required schemas})
      end

      it 'performs the action when using a password and scrubs any stack traces' do
        body = { target: {
          hostname: target[:host],
          user: target[:user],
          password: target[:password],
          port: target[:port]
        } }

        expect_any_instance_of(BoltServer::TransportApp)
          .to receive(:scrub_stack_trace).with(result.to_data).and_return({})

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end

      it 'performs an action when using a private key and scrubs any stack traces' do
        private_key = ENV['BOLT_SSH_KEY'] || Dir["spec/fixtures/keys/id_rsa"][0]
        private_key_content = File.read(private_key)

        body = { target: {
          hostname: target[:host],
          user: target[:user],
          'private-key-content': private_key_content,
          port: target[:port]
        } }

        expect_any_instance_of(BoltServer::TransportApp)
          .to receive(:scrub_stack_trace).with(result.to_data).and_return({})

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end

      it 'expects either a single target or a set of targets, but not both' do
        single_target = {
          hostname: target[:host],
          user: target[:user],
          password: target[:password],
          port: target[:port]
        }
        body = { target: single_target }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response.status).to eq(200)

        body = { targets: [single_target] }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response.status).to eq(200)

        body = { target: single_target, targets: single_target }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response.status).to eq(400)
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
          .to receive(:scrub_stack_trace).with(result.to_data).and_return({})

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end

      it 'expects either a single target or a set of targets, but not both' do
        single_target = {
          hostname: target[:host],
          user: target[:user],
          password: target[:password],
          port: target[:port]
        }
        body = { target: single_target }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response.status).to eq(200)

        body = { targets: [single_target] }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response.status).to eq(200)

        body = { target: single_target, targets: single_target }

        post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
        expect(last_response.status).to eq(400)
      end
    end
  end

  describe 'action endpoints' do
    # Helper to set the transport on a body hash, and then post to an action
    # endpoint (/ssh/<action> or /winrm/<action>) Set `:multiple` to send
    # a list of `targets` rather than a single `target` with the request.
    def post_over_transport(transport, action, body_content, multiple: false)
      path = "/#{transport}/#{action}"

      target_data = conn_info(transport)
      target = {
        hostname: target_data[:host],
        user: target_data[:user],
        password: target_data[:password],
        port: target_data[:port]
      }
      target[:'connect-timeout'] = target_data[:'connect-timeout'] if target_data[:'connect-timeout']

      body = if multiple
               body_content.merge(targets: [target])
             else
               body_content.merge(target: target)
             end

      post(path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json')
    end

    describe 'check_node_connections' do
      it 'checks node connections over SSH', :ssh do
        post_over_transport('ssh', 'check_node_connections', {}, multiple: true)

        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result['status']).to eq('success')
      end

      it 'checks node connections over WinRM', :winrm do
        post_over_transport('winrm', 'check_node_connections', {}, multiple: true)

        expect(last_response.status).to eq(200)
        result = JSON.parse(last_response.body)
        expect(result['status']).to eq('success')
        expect(result['result']).to be_a(Array)
        expect(result['result'].length).to eq(1)
        expect(result['result'].first['status']).to eq('success')
      end

      context 'when the checks succeed, but at least one node failed' do
        let(:successful_target) {
          target_data = conn_info('ssh')
          {
            hostname: target_data[:host],
            user: target_data[:user],
            password: target_data[:password],
            port: target_data[:port]
          }
        }

        let(:failed_target) {
          target = successful_target.clone
          target[:hostname] = 'not-a-real-host'
          target
        }

        it 'returns 200 but reports a "failure" status', :ssh do
          body = { targets: [successful_target, failed_target] }
          post('/ssh/check_node_connections', JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

          expect(last_response.status).to eq(200)
          response_body = JSON.parse(last_response.body)
          expect(response_body['status']).to eq('failure')
        end
      end
    end

    describe 'run_task' do
      describe 'over SSH', :ssh do
        let(:simple_ssh_task) {
          {
            task: { name: 'sample::echo',
                    metadata: {
                      description: 'Echo a message',
                      parameters: { message: 'Default message' }
                    },
                    files: [{ filename: "echo.sh", sha256: "foo",
                              uri: { path: 'foo', params: { environment: 'foo' } } }] },
            timeout: 0,
            parameters: { message: "Hello!" }
          }
        }

        it 'runs a simple echo task', :ssh do
          post_over_transport('ssh', 'run_task', simple_ssh_task)

          expect(last_response).to be_ok
          expect(last_response.status).to eq(200)

          result = JSON.parse(last_response.body)
          expect(result).to include('status' => 'success')
          expect(result['value']['_output']).to match(/got passed the message: Hello!/)
        end

        it 'errors if multiple targets are supplied', :ssh do
          post_over_transport('ssh', 'run_task', simple_ssh_task, multiple: true)

          expect(last_response.status).to eq(400)
          expect(last_response.body)
            .to match(%r{The property '#/' did not contain a required property of 'target'})
          expect(last_response.body)
            .to match(%r{The property '#/' contains additional properties \[\\"targets\\"\]})
        end
      end

      describe 'over WinRM' do
        let(:simple_winrm_task) {
          {
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
        }

        it 'runs a simple echo task', :winrm do
          post_over_transport('winrm', 'run_task', simple_winrm_task)

          expect(last_response).to be_ok
          expect(last_response.status).to eq(200)

          result = JSON.parse(last_response.body)
          expect(result).to include('status' => 'success')
          expect(result['value']['_output']).to match(/INPUT.*Hello!/)
        end

        it 'errors if multiple targets are supplied', :winrm do
          post_over_transport('winrm', 'run_task', simple_winrm_task, multiple: true)

          expect(last_response.status).to eq(400)
          expect(last_response.body)
            .to match(%r{The property '#/' did not contain a required property of 'target'})
          expect(last_response.body)
            .to match(%r{The property '#/' contains additional properties \[\\"targets\\"\]})
        end
      end

      describe 'sensitive task output', :ssh do
        let(:task_template) {
          {
            task: { name: 'sample::sensitive_task_output',
                    metadata: {},
                    files: [{ filename: "sensitive_task_output.sh", sha256: "foo",
                              uri: { path: 'foo', params: { environment: 'foo' } } }] }
          }
        }

        it "unwraps the Sensitive value under the output's _sensitive key", :ssh do
          task = task_template.merge('parameters' => { 'include_sensitive' => 'true' })
          post_over_transport('ssh', 'run_task', task)

          expect(last_response).to be_ok
          expect(last_response.status).to eq(200)

          result = JSON.parse(last_response.body)
          expect(result).to include('status' => 'success')
          expect(result['value']).to eql('user' => 'someone', '_sensitive' => { 'password' => 'secretpassword' })
        end

        it "noops if the output does not contain a _sensitive key", :ssh do
          task = task_template
          post_over_transport('ssh', 'run_task', task)

          expect(last_response).to be_ok
          expect(last_response.status).to eq(200)

          result = JSON.parse(last_response.body)
          expect(result).to include('status' => 'success')
          expect(result['value']).to eql('user' => 'someone')
        end
      end

      describe 'with a task timeout over ssh', :ssh do
        let(:ssh_timeout_task) {
          {
            task: { name: 'sample:sleep',
                    metadata: {
                      description: 'Echo a message',
                      parameters: {}
                    },
                    files: [{ filename: "sleep.sh", sha256: "foo",
                              uri: { path: 'foo', params: { environment: 'foo' } } }] },
            parameters: {},
            timeout: 2
          }
        }

        it 'runs a simple echo task', :ssh do
          post_over_transport('ssh', 'run_task', ssh_timeout_task)
          expect(last_response).not_to be_ok
          expect(last_response.status).to eq(500)
          result = JSON.parse(last_response.body)
          expect(result['kind']).to eq("boltserver/task-timeout")
        end
      end

      describe 'with a task timeout over WinRM', :winrm do
        let(:winrm_timeout_task) {
          {
            task: { name: 'sample:sleep',
                    metadata: {
                      description: 'Echo a message',
                      parameters: {}
                    },
                    files: [{ filename: "sleep.ps1", sha256: "foo",
                              uri: { path: 'foo', params: { environment: 'foo' } } }] },
            parameters: {},
            timeout: 2
          }
        }

        it 'runs a simple echo task', :ssh do
          post_over_transport('ssh', 'run_task', winrm_timeout_task)
          expect(last_response).not_to be_ok
          expect(last_response.status).to eq(500)
          result = JSON.parse(last_response.body)
          expect(result['kind']).to eq("boltserver/task-timeout")
        end
      end
    end
  end
end
