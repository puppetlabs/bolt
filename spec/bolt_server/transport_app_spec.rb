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
require 'pathname'

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
    config = BoltServer::Config.new({ 'projects-dir' => project_dir, 'environments-codedir' => basedir })
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

  def with_project(bolt_project, inventory_content, inventory_name = 'inventory.yaml')
    Dir.mktmpdir(nil, project_dir) do |tmpdir|
      File.write(File.join(tmpdir, 'bolt-project.yaml'), bolt_project.to_yaml)
      File.write(File.join(tmpdir, inventory_name), inventory_content.to_yaml) unless inventory_content.nil?
      yield tmpdir
    end
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

        context 'with a non-existant environment' do
          let(:path) { "/plans?environment=not_an_env" }
          it 'returns 400 if an environment not found error is thrown' do
            get(path)
            expect(last_response.status).to eq(400)
          end
        end

        context 'with a non existant environment' do
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
        let(:path) { "/project_plans/bolt_server_test_project/simple_plan?versioned_project=bolt_server_test_project" }
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
        let(:init_plan) { "/project_plans/bolt_server_test_project/init?versioned_project=bolt_server_test_project" }
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

      context 'allowlist contains a glob' do
        let(:plan) do
          "/project_plans/bolt_server_test_project/allowlist_glob?versioned_project=bolt_server_test_project"
        end
        let(:expected_response) {
          {
            'name' => 'bolt_server_test_project::allowlist_glob',
            'description' => 'Project plan testing',
            'parameters' => { 'foo' => { 'sensitive' => false, 'type' => 'String' } },
            'allowed' => true
          }
        }
        it 'properly filters allowed and disallowed plans' do
          get(plan)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with non-existant plan' do
        let(:path) { "/project_plans/foo/bar?versioned_project=bolt_server_test_project" }
        it 'returns 404 if an unknown plan error is thrown' do
          get(path)
          expect(last_response.status).to eq(404)
          err = JSON.parse(last_response.body)
          expect(err['kind']).to eq('bolt-server/request-error')
          expect(err['msg']).to eq("Could not find a plan named 'foo::bar'")
        end
      end
    end

    describe '/project_plans' do
      describe 'when requesting plan list' do
        context 'with an existing project' do
          let(:path) { "/project_plans?versioned_project=bolt_server_test_project" }
          it 'returns the plans and filters based on allowlist in bolt-project.yaml' do
            get(path)
            metadata = JSON.parse(last_response.body)
            expect(metadata).to include(
              { 'name' => 'bolt_server_test_project', 'allowed' => true },
              { 'name' => 'bolt_server_test_project::simple_plan', 'allowed' => false },
              { 'name' => 'bolt_server_test_project::allowlist_glob', 'allowed' => true }
            )
          end
        end

        context 'with a non existant project' do
          let(:path) { "/project_plans/foo/bar?versioned_project=not_a_real_project" }
          it 'returns 400 if an versioned_project not found error is thrown' do
            get(path)
            error = JSON.parse(last_response.body)
            expect(error['msg']).to match(/not_a_real_project' does not exist/)
            expect(last_response.status).to eq(400)
          end
        end
      end
    end

    describe '/tasks' do
      context 'with a non existant environment' do
        let(:path) { "/tasks?environment=production" }
        it 'returns just the list of task names' do
          get(path)
          metadata = JSON.parse(last_response.body)
          expect(metadata).to include({ 'name' => 'bolt_server_test' }, { 'name' => 'bolt_server_test::simple_task' })
        end
      end

      context 'with a non existant environment' do
        let(:path) { "/tasks?environment=not_a_real_env" }
        it 'returns 400 if an environment not found error is thrown' do
          get(path)
          expect(last_response.status).to eq(400)
        end
      end

      context 'with a non existant environment' do
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

    describe '/project_tasks' do
      context 'with an existing project' do
        let(:path) { "/project_tasks?versioned_project=bolt_server_test_project" }
        it 'returns the tasks and filters based on allowlist in bolt-project.yaml' do
          get(path)
          metadata = JSON.parse(last_response.body)
          expect(metadata).to include(
            { 'name' => 'bolt_server_test_project', 'allowed' => true },
            { 'name' => 'bolt_server_test_project::hidden', 'allowed' => false },
            { 'name' => 'bolt_server_test_project::allowlist_glob', 'allowed' => true }
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

      context 'with non-existant task' do
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

    describe '/project_tasks/:module_name/:task_name' do
      context 'with module_name::task_name' do
        let(:path) { "/project_tasks/bolt_server_test_project/hidden?versioned_project=bolt_server_test_project" }
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
                  "params" => { "versioned_project" => 'bolt_server_test_project' }
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
        let(:path) { "/project_tasks/bolt_server_test_project/init?versioned_project=bolt_server_test_project" }
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
                  "params" => { "versioned_project" => 'bolt_server_test_project' }
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

      context 'with non-existant task' do
        let(:path) { "/project_tasks/foo/bar?versioned_project=bolt_server_test_project" }
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
    end

    describe '/project_inventory_targets' do
      let(:bolt_project) { { 'name' => 'my_project' } }
      let(:targets) { %w[one two three] }
      let(:bolt_inventory) { { 'targets' => targets } }

      def post_to_project_inventory_targets(versioned_project, connect_data = { 'puppet_connect_data' => {} })
        path = "/project_inventory_targets?versioned_project=#{versioned_project}"
        post(path, JSON.generate(connect_data), 'CONTENT_TYPE' => 'text/json')
      end

      it 'parses inventory' do
        with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
          versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
          post_to_project_inventory_targets(versioned_project)
          expect(last_response.status).to eq(200)
          target_list = JSON.parse(last_response.body)
          target_names = target_list.map do |targ|
            expect(targ).to include('name')
            expect(targ).to include('transport')
            targ['name']
          end
          expect(target_names.sort).to eq(targets.sort)
        end
      end

      context 'when transport is different than protocol' do
        let(:targets) {
          [{
            'uri' => 'ssh://foo.com',
            'config' => {
              'transport' => 'remote'
            }
          }]
        }
        it 'sets transport independent from protocol' do
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project)
            expect(last_response.status).to eq(200)
            target_list = JSON.parse(last_response.body)
            expect(target_list.first['transport']).to eq('remote')
            expect(target_list.first['protocol']).to eq('ssh')
          end
        end
      end

      context 'when inventory cannot be processed' do
        let(:targets) {
          [{ 'oops' => 'bad target' }]
        }
        it 'responds with a 500 and error details' do
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project)
            expect(last_response.status).to eq(500)
            error_hash = JSON.parse(last_response.body)
            expect(error_hash['kind']).to eq('bolt.inventory/validation-error')
          end
        end
      end

      context 'when inventory file is absent' do
        it 'responds with a 500 and error details' do
          with_project(bolt_project, nil) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project)
            expect(last_response.status).to eq(500)
            error_hash = JSON.parse(last_response.body)
            expect(error_hash['kind']).to eq('bolt/file-error')
          end
        end
      end

      context 'with unknown plugin' do
        let(:targets) {
          [{ 'name' => { '_plugin' => 'foo' } }]
        }
        it 'responds with a 500 and error details' do
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project)
            expect(last_response.status).to eq(500)
            error_hash = JSON.parse(last_response.body)
            expect(error_hash['kind']).to eq('bolt/unknown-plugin')
          end
        end
      end

      context 'with disabled plugin in target list' do
        let(:targets) {
          [{ 'name' => { '_plugin' => 'prompt' } }]
        }
        it 'responds with a 500 and error details' do
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project)
            expect(last_response.status).to eq(500)
            error_hash = JSON.parse(last_response.body)
            expect(error_hash['kind']).to eq('bolt/plugin-not-supported')
            expect(error_hash.dig('details', 'plugin_name')).to eq('prompt')
          end
        end
      end

      context 'with disabled plugin in inventory config' do
        let(:targets) {
          [{ 'name' => 'foo', 'config' => { '_plugin' => 'prompt' } }]
        }
        it 'responds with a 500 and error details' do
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project)
            expect(last_response.status).to eq(500)
            error_hash = JSON.parse(last_response.body)
            expect(error_hash['kind']).to eq('bolt/plugin-not-supported')
            expect(error_hash.dig('details', 'plugin_name')).to eq('prompt')
          end
        end
      end

      context 'with puppet_connect_data plugin' do
        let(:targets) {
          [
            {
              'name' => {
                '_plugin' => 'puppet_connect_data',
                'key' => 'target_name'
              },
              'config' => {
                'ssh' => {
                  'password' => {
                    '_plugin' => 'puppet_connect_data',
                    'key' => 'target_password'
                  }
                }
              }
            }
          ]
        }

        it 'looks up data included in request' do
          connect_data = {
            'puppet_connect_data' => {
              'target_name' => {
                'value' => 'foo'
              },
              'target_password' => {
                'value' => 'bar'
              }
            }
          }
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project, connect_data)
            expect(last_response.status).to eq(200)
            target_list = JSON.parse(last_response.body)
            expect(target_list.count).to eq(1)
            expect(target_list.first['name']).to eq('foo')
            expect(target_list.first['password']).to eq('bar')
          end
        end

        it 'connect plugin fails when "key" is not specified in inventoryfile' do
          connect_data = {
            'puppet_connect_data' => {
              'target_name' => {
                'value' => 'foo'
              },
              'target_password' => {
                'value' => 'bar'
              }
            }
          }
          targets.first['name'].delete('key')
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project, connect_data)
            expect(last_response.status).to eq(500)
            expect(last_response.body).to match(/puppet_connect_data plugin requires that 'key' be specified/)
          end
        end

        it 'errors when connect_data is not included in the request' do
          connect_data = {}
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project, connect_data)
            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/did not contain a required property of 'puppet_connect_data'/)
          end
        end

        it 'errors when connect_data entry does not have a "value"' do
          connect_data = {
            'puppet_connect_data' => {
              'oops_missing_value' => {
                'not_value' => 'foo'
              }
            }
          }
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project, connect_data)
            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/did not contain a required property of 'value'/)
          end
        end
      end

      context "parsing the target's plugin hooks" do
        it 'defaults to a puppet_library plugin hook that uses the task plugin set to puppet_agent::install' do
          with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
            versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
            post_to_project_inventory_targets(versioned_project)
            expect(last_response.status).to eq(200)
            target_list = JSON.parse(last_response.body)
            expect(target_list.first['plugin_hooks'].size).to eql(1)
            expect(target_list.first['plugin_hooks']).to include('puppet_library')
            expect(target_list.first['plugin_hooks']['puppet_library']['plugin']).to eql('task')
            expect(target_list.first['plugin_hooks']['puppet_library']['task']).to eql('puppet_agent::install')
            expect(target_list.first['plugin_hooks']['puppet_library']['parameters']).to eql('stop_service' => true)
          end
        end

        context 'when the user specifies a default for plugin hooks' do
          let(:user_specified_plugin_hooks) do
            { 'resolve_reference' => {} }
          end
          let(:bolt_project) do
            super().merge('plugin-hooks' => user_specified_plugin_hooks)
          end

          context 'when the user does not specify a default for the puppet_library plugin hook' do
            it 'returns the default puppet_library plugin hook while preserving the other defaults' do
              with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
                versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
                post_to_project_inventory_targets(versioned_project)
                expect(last_response.status).to eq(200)
                target_list = JSON.parse(last_response.body)
                expect(target_list.first['plugin_hooks']).to include('resolve_reference')
                expect(target_list.first['plugin_hooks']).to include('puppet_library')
                expect(target_list.first['plugin_hooks']['puppet_library']['task']).to eql('puppet_agent::install')
                expect(target_list.first['plugin_hooks']['puppet_library']['task']).to eql('puppet_agent::install')
              end
            end
          end

          context 'when the user specifies a default for the puppet_library plugin hook' do
            let(:user_specified_plugin_hooks) do
              super().merge('puppet_library' => { 'plugin' => 'puppet_agent' })
            end

            it 'returns the user-specified defaults' do
              with_project(bolt_project, bolt_inventory) do |path_to_tmp_project|
                versioned_project = path_to_tmp_project.split(File::SEPARATOR).last
                post_to_project_inventory_targets(versioned_project)
                expect(last_response.status).to eq(200)
                target_list = JSON.parse(last_response.body)
                expect(target_list.first['plugin_hooks']).to include('resolve_reference')
                expect(target_list.first['plugin_hooks']).to include('puppet_library')
                expect(target_list.first['plugin_hooks']['puppet_library']['plugin']).to eql('puppet_agent')
              end
            end
          end
        end
      end

      it 'errors when versioned_project is invalid' do
        post_to_project_inventory_targets('foo')
        expect(last_response.status).to eq(400)
        error = JSON.parse(last_response.body)
        expect(error['msg']).to match(/foo' does not exist/)
      end
    end

    describe '/project_file_metadatas/:module_name/:file' do
      let(:versioned_project) { 'bolt_server_test_project' }

      it 'returns 400 if versioned_project is not specified' do
        get('/project_file_metadatas/foo_module/foo_file')
        expect(last_response.status).to eq(400)
        error = JSON.parse(last_response.body)
        expect(error['msg']).to match("'versioned_project' is a required argument")
      end

      it 'returns 400 if versioned_project does not exist' do
        get("/project_file_metadatas/bar/foo?versioned_project=not_a_real_project")
        expect(last_response.status).to eq(400)
        error = JSON.parse(last_response.body)
        expect(error['msg']).to match(/not_a_real_project' does not exist/)
      end

      it 'returns 400 if module_name does not exist' do
        get("/project_file_metadatas/bar/foo?versioned_project=#{versioned_project}")
        expect(last_response.status).to eq(400)
        error = JSON.parse(last_response.body)
        expect(error['msg']).to match(/bar' does not exist/)
      end

      it 'returns 400 if file does not exist in the module' do
        get("/project_file_metadatas/project_module/not_a_real_file?versioned_project=#{versioned_project}")
        expect(last_response.status).to eq(400)
        error = JSON.parse(last_response.body)
        expect(error['msg']).to match(/not_a_real_file' does not exist/)
      end

      context "with a valid filepath to one file", ssh: true do
        let(:test_file) {
          Pathname.new(
            File.join(project_dir, versioned_project, 'modules', 'project_module', 'files', 'test_file')
          ).cleanpath.to_s
        }
        let(:file_checksum) {
          Digest::SHA256.hexdigest(
            File.read(test_file)
          )
        }
        let(:expected_response) {
          [
            {
              "path" => test_file,
              "relative_path" => ".",
              "links" => "follow",
              "owner" => File.stat(test_file).uid,
              "group" => File.stat(test_file).gid,
              "checksum" => {
                "type" => "sha256",
                "value" => "{sha256}#{file_checksum}"
              },
              "type" => "file",
              "destination" => nil
            }
          ]
        }
        it 'returns the file metadata of the file and all its children' do
          get("/project_file_metadatas/project_module/test_file?versioned_project=#{versioned_project}")
          file_metadatas = JSON.parse(last_response.body)
          # I don't know why the mode returned by puppet is not the same as the mode returned
          # from ruby's File.stat(test_file) function. But these tests probably don't need to
          # cover the specifics of what puppet returns, plus we don't use this metadata in
          # orch anyway, so ignore the mode part of the respose.
          #                                     - Sean P. McDonald 10/15/2020
          file_metadatas.each do |entry|
            entry.delete("mode")
          end
          expect(file_metadatas).to eq(expected_response)
          expect(last_response.status).to eq(200)
        end
      end

      context "when the file path contains '/'", ssh: true do
        let(:test_file) {
          Pathname.new(
            File.join(project_dir, versioned_project, 'modules', 'project_module', 'files', 'test_dir', 'test_dir_file')
          ).cleanpath.to_s
        }
        let(:file_checksum) {
          Digest::SHA256.hexdigest(
            File.read(test_file)
          )
        }
        let(:expected_response) {
          [
            {
              "path" => test_file,
              "relative_path" => ".",
              "links" => "follow",
              "owner" => File.stat(test_file).uid,
              "group" => File.stat(test_file).gid,
              "checksum" => {
                "type" => "sha256",
                "value" => "{sha256}#{file_checksum}"
              },
              "type" => "file",
              "destination" => nil
            }
          ]
        }
        it 'returns the file metadata of the file and all its children' do
          get("/project_file_metadatas/project_module/test_dir/test_dir_file?versioned_project=#{versioned_project}")
          file_metadatas = JSON.parse(last_response.body)
          # I don't know why the mode returned by puppet is not the same as the mode returned
          # from ruby's File.stat(test_file) function. But these tests probably don't need to
          # cover the specifics of what puppet returns, plus we don't use this metadata in
          # orch anyway, so ignore the mode part of the respose.
          #                                     - Sean P. McDonald 10/15/2020
          file_metadatas.each do |entry|
            entry.delete("mode")
          end
          expect(file_metadatas).to eq(expected_response)
          expect(last_response.status).to eq(200)
        end
      end

      context "with a directory", ssh: true do
        let(:test_dir) {
          Pathname.new(
            File.join(project_dir, versioned_project, 'modules', 'project_module', 'files', 'test_dir')
          ).cleanpath.to_s
        }
        let(:file_in_dir) {
          File.join(test_dir, 'test_dir_file')
        }
        let(:file_checksum) {
          Digest::SHA256.hexdigest(
            File.read(file_in_dir)
          )
        }
        let(:expected_response) {
          [
            {
              "path" => test_dir,
              "relative_path" => ".",
              "links" => "follow",
              "owner" => File.stat(test_dir).uid,
              "group" => File.stat(test_dir).gid,
              "checksum" => {
                "type" => "ctime",
                "value" => "{ctime}#{File.ctime(test_dir)}"
              },
              "type" => "directory",
              "destination" => nil
            },
            {
              "path" => test_dir,
              "relative_path" => "test_dir_file",
              "links" => "follow",
              "owner" => File.stat(file_in_dir).uid,
              "group" => File.stat(file_in_dir).gid,
              "checksum" => {
                "type" => "sha256",
                "value" => "{sha256}#{file_checksum}"
              },
              "type" => "file",
              "destination" => nil
            }
          ]
        }
        it 'returns the file metadata of the file and all its children' do
          get("/project_file_metadatas/project_module/test_dir?versioned_project=#{versioned_project}")
          file_metadatas = JSON.parse(last_response.body)
          # I don't know why the mode returned by puppet is not the same as the mode returned
          # from ruby's File.stat(test_file) function. But these tests probably don't need to
          # cover the specifics of what puppet returns, plus we don't use this metadata in
          # orch anyway, so ignore the mode part of the respose.
          #                                     - Sean P. McDonald 10/15/2020
          file_metadatas.each do |entry|
            entry.delete("mode")
          end
          expect(file_metadatas).to eq(expected_response)
          expect(last_response.status).to eq(200)
        end
      end
    end
  end
end
