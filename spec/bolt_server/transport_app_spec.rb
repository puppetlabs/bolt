# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/bolt_server'
require 'bolt_spec/conn'
require 'bolt_spec/file_cache'
require 'bolt_server/config'
require 'bolt_server/transport_app'
require 'json'
require 'rack/test'
require 'puppet/environments'
require 'digest'

describe "BoltServer::TransportApp" do
  include BoltSpec::BoltServer
  include BoltSpec::Conn
  include BoltSpec::FileCache
  include Rack::Test::Methods

  let(:basedir) { File.join(__dir__, '..', 'fixtures', 'bolt_server') }
  let(:environment_dir) { File.join(basedir, 'environments', 'production') }
  let(:project_dir) { File.join(basedir, 'projects') }

  def app
    # The moduledir and mock file cache are used in the tests for task
    # execution tests. Everything else uses the fixtures above.
    moduledir = File.join(__dir__, '..', 'fixtures', 'modules')
    mock_file_cache(moduledir)
    config = BoltServer::Config.new({ 'projects-dir' => project_dir })
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

  before(:each) do
    stub_const('BoltServer::TransportApp::DEFAULT_BOLT_CODEDIR', basedir)
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
    let(:result) { double(Bolt::Result, to_data: { 'status': 'test_status' }) }

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
            'parameters' => { 'foo' => { 'sensitive' => false, 'type' => 'String' } }
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
            'parameters' => { 'bar' => { 'sensitive' => false, 'type' => 'String' } }
          }
        }
        it '/plans/:module_name/:plan_name handles plan name = module name (init.pp) plan' do
          get(init_plan)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end
      context 'with non-existant plan' do
        let(:path) { '/plans/foo/bar?environment=production' }
        it 'returns 400 if an unknown plan error is thrown' do
          get(path)
          expect(last_response.status).to eq(400)
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

        context 'with a non-existant environment' do
          let(:path) { "/plans?environment=not_an_env" }
          it 'returns 400 if an environment not found error is thrown' do
            get(path)
            expect(last_response.status).to eq(400)
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
              'parameters' => { 'bar' => { 'sensitive' => false, 'type' => 'String' } }
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

    describe '/project_plans/:module_name/:plan_name' do
      context 'with module_name::plan_name' do
        let(:path) { "/project_plans/bolt_server_test_project/simple_plan?project_ref=bolt_server_test_project" }
        let(:expected_response) {
          {
            'name' => 'bolt_server_test_project::simple_plan',
            'description' => 'Simple plan testing',
            'parameters' => { 'foo' => { 'sensitive' => false, 'type' => 'String' } },
            'allowed' => false
          }
        }
        it '/project_plans/:module_name/:plan_name handles module::plan_name' do
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with module_name' do
        let(:init_plan) { "/project_plans/bolt_server_test_project/init?project_ref=bolt_server_test_project" }
        let(:expected_response) {
          {
            'name' => 'bolt_server_test_project',
            'description' => 'Project plan testing',
            'parameters' => { 'foo' => { 'sensitive' => false, 'type' => 'String' } },
            'allowed' => true
          }
        }
        it '/project_plans/:module_name/:plan_name handles plan name = module name (init.pp) plan' do
          get(init_plan)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with non-existant plan' do
        let(:path) { "/project_plans/foo/bar?project_ref=not_a_real_project" }
        it 'returns 400 if an unknown plan error is thrown' do
          get(path)
          expect(last_response.status).to eq(400)
        end
      end
    end

    describe '/project_plans' do
      describe 'when requesting plan list' do
        context 'with an existing project' do
          let(:path) { "/project_plans?project_ref=bolt_server_test_project" }
          it 'returns the plans and filters based on allowlist in bolt-project.yaml' do
            get(path)
            metadata = JSON.parse(last_response.body)
            expect(metadata).to include(
              { 'name' => 'bolt_server_test_project', 'allowed' => true },
              { 'name' => 'bolt_server_test_project::simple_plan', 'allowed' => false }
            )
          end
        end

        context 'with a non existant project' do
          let(:path) { "/project_plans/foo/bar?project_ref=not_a_real_project" }
          it 'returns 400 if an project_ref not found error is thrown' do
            get(path)
            error = last_response.body
            expect(error).to eq("`project_ref`: #{project_dir}/not_a_real_project does not exist")
            expect(last_response.status).to eq(400)
          end
        end
      end
    end

    describe '/tasks' do
      context 'with a non existant project' do
        let(:path) { "/tasks?environment=production" }
        it 'returns just the list of task names' do
          get(path)
          metadata = JSON.parse(last_response.body)
          expect(metadata).to include({ 'name' => 'bolt_server_test' }, { 'name' => 'bolt_server_test::simple_task' })
        end
      end

      context 'with a non existant project' do
        let(:path) { "/tasks?environment=not_a_real_env" }
        it 'returns 400 if an environment not found error is thrown' do
          get(path)
          expect(last_response.status).to eq(400)
        end
      end
    end

    describe '/project_tasks' do
      context 'with an existing project' do
        let(:path) { "/project_tasks?project_ref=bolt_server_test_project" }
        it 'returns the tasks and filters based on allowlist in bolt-project.yaml' do
          get(path)
          metadata = JSON.parse(last_response.body)
          expect(metadata).to include(
            { 'name' => 'bolt_server_test_project', 'allowed' => true },
            { 'name' => 'bolt_server_test_project::hidden', 'allowed' => false }
          )
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
    end

    describe '/project_tasks/:module_name/:task_name' do
      context 'with module_name::task_name' do
        let(:path) { "/project_tasks/bolt_server_test_project/hidden?project_ref=bolt_server_test_project" }
        let(:expected_response) {
          {
            "metadata" => { "description" => "Project task testing" },
            "name" => "bolt_server_test_project::hidden",
            "files" => [
              {
                "filename" => "hidden.sh",
                "sha256" => Digest::SHA256.hexdigest(
                  File.read(
                    File.join(project_dir, 'bolt_server_test_project', 'tasks', 'hidden.sh')
                  )
                ),
                "size_bytes" => File.size(
                  File.join(project_dir, 'bolt_server_test_project', 'tasks', 'hidden.sh')
                ),
                "uri" => {
                  "path" => "/puppet/v3/file_content/tasks/bolt_server_test_project/hidden.sh",
                  "params" => { "project" => 'bolt_server_test_project' }
                }
              }
            ],
            "allowed" => false
          }
        }
        it '/project_tasks/:module_name/:task_name handles module::task_name' do
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with module_name' do
        let(:path) { "/project_tasks/bolt_server_test_project/init?project_ref=bolt_server_test_project" }
        let(:expected_response) {
          {
            "metadata" => { "description" => "Project task testing" },
            "name" => "bolt_server_test_project",
            "files" => [
              {
                "filename" => "init.sh",
                "sha256" => Digest::SHA256.hexdigest(
                  File.read(
                    File.join(project_dir, 'bolt_server_test_project', 'tasks', 'init.sh')
                  )
                ),
                "size_bytes" => File.size(
                  File.join(project_dir, 'bolt_server_test_project', 'tasks', 'init.sh')
                ),
                "uri" => {
                  "path" => "/puppet/v3/file_content/tasks/bolt_server_test_project/init.sh",
                  "params" => { "project" => 'bolt_server_test_project' }
                }
              }
            ],
            "allowed" => true
          }
        }

        it '/prject_tasks/:module_name/:task_name handles task name = module name (init.rb) task' do
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
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
        expect(result['value']['_error']['details'].join).to match(regex)
        expect(result['status']).to eq('failure')
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
        body = { 'target': {
          'hostname': target[:host],
          'user': target[:user],
          'password': target[:password],
          'port': target[:port]
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

        body = { 'target': {
          'hostname': target[:host],
          'user': target[:user],
          'private-key-content': private_key_content,
          'port': target[:port]
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

        it 'overrides host-key-check default', :ssh do
          target = conn_info('ssh')
          body = {
            target: {
              hostname: target[:host],
              user: target[:user],
              password: target[:password],
              port: target[:port],
              'host-key-check': true
            },
            task: { name: 'sample::echo',
                    metadata: {
                      description: 'Echo a message',
                      parameters: { message: 'Default message' }
                    },
                    files: [{ filename: "echo.sh", sha256: "foo",
                              uri: { path: 'foo', params: { environment: 'foo' } } }] },
            parameters: { message: "Hello!" }
          }

          post('ssh/run_task', JSON.generate(body), 'CONTENT_TYPE' => 'text/json')

          result = last_response.body
          expect(result).to match(/Host key verification failed for localhost/)
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
    end

    describe '/project_file_metadatas/:module_name/:file' do
      let(:fake_pal) { instance_double('Bolt::PAL') }
      let(:fake_project) { instance_double('Bolt::Project') }
      let(:fake_config) { instance_double('Bolt::Config') }
      let(:fake_environment) { instance_double('Puppet::Node::Environment') }
      let(:fake_module) { instance_double('Puppet::Module') }
      let(:fake_file) { 'foo_file_abs_path' }
      let(:fake_fileset) { instance_double('Puppet::FileServing::Fileset') }
      let(:project_ref) { 'some_project_somesha' }
      let(:module_name) { 'foo_module' }
      let(:file) { 'foo_file' }
      let(:path) { "/project_file_metadatas/#{module_name}/#{file}?project_ref=#{project_ref}" }

      before(:each) do
        allow(Dir).to receive(:exist?).with("/tmp/foo/#{project_ref}").and_return(true)
        allow(Bolt::Project).to receive(:create_project).and_return(fake_project)
        allow(Bolt::Config).to receive(:from_project).and_return(fake_config)
        allow(fake_config).to receive(:modulepath)
        allow(fake_config).to receive(:project).and_return(fake_project)
        allow(Bolt::PAL).to receive(:new).and_return(fake_pal)
        allow(fake_pal).to receive(:in_bolt_compiler).and_yield
        allow(Puppet).to receive(:lookup).with(:current_environment).and_return(fake_environment)
        allow(fake_environment).to receive(:module).with(module_name).and_return(fake_module)
        allow(fake_module).to receive(:file).with(file).and_return(fake_file)
        # The Puppet::FileServing code will be tested more thoroughly in Orch's acceptance
        # tests so it is enough for the unit tests to make sure that we're returning a 200
        # status when the metadata's retrieved.
        allow(Puppet::FileServing::Fileset).to receive(:new).with(fake_file, anything).and_return(fake_fileset)
        allow(Puppet::FileServing::Fileset).to receive(:merge).with(fake_fileset).and_return([])
      end

      it 'returns 400 if project_ref is not specified' do
        path = '/project_file_metadatas/foo_module/foo_file'
        get(path)
        error = last_response.body
        expect(error).to eq("`project_ref` is a required argument")
        expect(last_response.status).to eq(400)
      end

      it 'returns 400 if project_ref does not exist' do
        allow(Dir).to receive(:exist?).with("/tmp/foo/#{project_ref}").and_return(false)
        get(path)
        error = last_response.body
        expect(error).to eq("`project_ref`: /tmp/foo/#{project_ref} does not exist")
        expect(last_response.status).to eq(400)
      end

      it 'returns 400 if module_name does not exist' do
        allow(fake_environment).to receive(:module).with(module_name).and_return(nil)
        get(path)
        error = last_response.body
        expect(error).to eq("`module_name`: #{module_name} does not exist")
        expect(last_response.status).to eq(400)
      end

      it 'returns 400 if file does not exist in the module' do
        allow(fake_module).to receive(:file).with(file).and_return(nil)
        get(path)
        error = last_response.body
        expect(error).to eq("`file`: #{file} does not exist inside the module's 'files' directory")
        expect(last_response.status).to eq(400)
      end

      it 'returns the file metadata of the file and all its children' do
        get(path)
        file_metadatas = last_response.body
        expect(file_metadatas).to eq("[]")
        expect(last_response.status).to eq(200)
      end

      context "when the file path contains '/'" do
        let(:file) { "foo/bar" }

        it 'returns the file metadata of the file and all its children' do
          get(path)
          file_metadatas = last_response.body
          expect(file_metadatas).to eq("[]")
          expect(last_response.status).to eq(200)
        end
      end
    end
  end
end
