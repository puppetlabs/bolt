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
      let(:fake_pal) { instance_double('BoltServer::PE::PAL') }

      context 'with module_name::plan_name' do
        let(:path) { '/plans/foo/bar?environment=production' }
        let(:plan_name) { 'foo::bar' }
        let(:metadata) { mock_plan_info(plan_name) }
        let(:expected_response) {
          {
            'name' => metadata['name'],
            'description' => metadata['description'],
            'parameters' => metadata['parameters']
          }
        }
        it '/plans/:module_name/:plan_name handles module::plan_name' do
          expect(BoltServer::PE::PAL).to receive(:new).and_return(fake_pal)
          expect(fake_pal).to receive(:get_plan_info).with(plan_name).and_return(metadata)
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with module_name' do
        let(:init_plan) { '/plans/foo/init?environment=production' }
        let(:plan_name) { 'foo' }
        let(:metadata) { mock_plan_info(plan_name) }
        let(:expected_response) {
          {
            'name' => metadata['name'],
            'description' => metadata['description'],
            'parameters' => metadata['parameters']
          }
        }
        it '/plans/:module_name/:plan_name handles plan name = module name (init.pp) plan' do
          expect(BoltServer::PE::PAL).to receive(:new).and_return(fake_pal)
          expect(fake_pal).to receive(:get_plan_info).with(plan_name).and_return(metadata)
          get(init_plan)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end
      context 'with non-existant plan' do
        let(:path) { '/plans/foo/bar?environment=production' }
        it 'returns 400 if an unknown plan error is thrown' do
          expect(BoltServer::PE::PAL).to receive(:new).and_return(fake_pal)
          expect(fake_pal).to receive(:get_plan_info).with('foo::bar').and_raise(Bolt::Error.unknown_plan('foo::bar'))
          get(path)
          expect(last_response.status).to eq(400)
        end
      end
    end

    describe '/plans' do
      let(:fake_pal) { instance_double('BoltServer::PE::PAL') }

      describe 'when metadata=false' do
        let(:path) { "/plans?environment=production" }
        it 'returns just the list of plan names when metadata=false' do
          expect(BoltServer::PE::PAL).to receive(:new).and_return(fake_pal)
          expect(fake_pal).to receive(:list_plans).and_return([['abc'], ['def']])
          get(path)
          metadata = JSON.parse(last_response.body)
          expect(metadata).to eq([{ 'name' => 'abc' }, { 'name' => 'def' }])
        end

        it 'returns 400 if an environment not found error is thrown' do
          # Actually creating the EnvironmentNotFound error with puppet is difficult to do without
          # puppet actually loaded with settings, so just stub out the error type
          stub_const("Puppet::Environments::EnvironmentNotFound", StandardError)
          expect(BoltServer::PE::PAL).to receive(:new).and_raise(Puppet::Environments::EnvironmentNotFound)
          get(path)
          expect(last_response.status).to eq(400)
        end
      end

      describe 'when metadata=true' do
        let(:path) { '/plans?environment=production&metadata=true' }
        let(:plan_name) { 'abc' }
        let(:metadata) { mock_plan_info(plan_name) }
        let(:expected_response) {
          {
            metadata['name'] => {
              'name' => metadata['name'],
              'description' => metadata['description'],
              'parameters' => metadata['parameters']
            }
          }
        }
        it 'returns all metadata for each plan when metadata=true' do
          expect(BoltServer::PE::PAL).to receive(:new).and_return(fake_pal)
          expect(fake_pal).to receive(:list_plans).and_return([plan_name])
          expect(fake_pal).to receive(:get_plan_info).with(plan_name).and_return(metadata)
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end
    end

    describe '/project_plans/:module_name/:plan_name' do
      let(:fake_pal) { instance_double('Bolt::PAL') }
      let(:fake_project) { instance_double('Bolt::Project') }
      let(:fake_config) { instance_double('Bolt::Config') }
      let(:project_ref) { 'some_project_somesha' }

      before(:each) do
        allow(Dir).to receive(:exist?).with("/tmp/foo/#{project_ref}").and_return(true)
        allow(Bolt::Project).to receive(:create_project).and_return(fake_project)
        allow(Bolt::Config).to receive(:from_project).and_return(fake_config)
        allow(fake_config).to receive(:modulepath)
        allow(fake_config).to receive(:project).and_return(fake_project)
        allow(Bolt::PAL).to receive(:new).and_return(fake_pal)
      end

      context 'with module_name::plan_name' do
        let(:path) { "/project_plans/foo/bar?project_ref=#{project_ref}" }
        let(:plan_name) { 'foo::bar' }
        let(:metadata) { mock_plan_info(plan_name) }
        let(:expected_response) {
          {
            'name' => metadata['name'],
            'description' => metadata['description'],
            'parameters' => metadata['parameters'],
            'allowed' => true
          }
        }
        it '/project_plans/:module_name/:plan_name handles module::plan_name' do
          allow(fake_project).to receive(:plans)
          expect(fake_pal).to receive(:get_plan_info).with(plan_name).and_return(metadata)
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with module_name' do
        let(:init_plan) { "/project_plans/foo/init?project_ref=#{project_ref}" }
        let(:plan_name) { 'foo' }
        let(:metadata) { mock_plan_info(plan_name) }
        let(:expected_response) {
          {
            'name' => metadata['name'],
            'description' => metadata['description'],
            'parameters' => metadata['parameters'],
            'allowed' => true
          }
        }
        it '/project_plans/:module_name/:plan_name handles plan name = module name (init.pp) plan' do
          allow(fake_project).to receive(:plans)
          expect(fake_pal).to receive(:get_plan_info).with(plan_name).and_return(metadata)
          get(init_plan)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with non-existant plan' do
        let(:path) { "/project_plans/foo/bar?project_ref=#{project_ref}" }
        it 'returns 400 if an unknown plan error is thrown' do
          expect(fake_pal).to receive(:get_plan_info).with('foo::bar').and_raise(Bolt::Error.unknown_plan('foo::bar'))
          get(path)
          expect(last_response.status).to eq(400)
        end
      end
    end

    describe '/project_plans' do
      let(:fake_pal) { instance_double('Bolt::PAL') }
      let(:fake_project) { instance_double('Bolt::Project') }
      let(:fake_config) { instance_double('Bolt::Config') }
      let(:project_ref) { 'some_project_somesha' }

      before(:each) do
        allow(Bolt::Project).to receive(:create_project).and_return(fake_project)
        allow(Bolt::Config).to receive(:from_project).and_return(fake_config)
        allow(fake_config).to receive(:modulepath)
        allow(fake_config).to receive(:project).and_return(fake_project)
        allow(Bolt::PAL).to receive(:new).and_return(fake_pal)
      end

      describe 'when requesting plan list' do
        let(:path) { "/project_plans?project_ref=#{project_ref}" }
        it 'returns just the list of plan names' do
          allow(Dir).to receive(:exist?).with("/tmp/foo/#{project_ref}").and_return(true)
          allow(fake_project).to receive(:plans)
          expect(fake_pal).to receive(:list_plans).and_return([['abc'], ['def']])
          get(path)
          metadata = JSON.parse(last_response.body)
          expect(metadata).to eq([{ 'name' => 'abc', 'allowed' => true }, { 'name' => 'def', 'allowed' => true }])
        end

        it 'filters plans based on allowlist in bolt-project.yaml' do
          allow(Dir).to receive(:exist?).with("/tmp/foo/#{project_ref}").and_return(true)
          allow(fake_project).to receive(:plans).and_return(['abc'])
          expect(fake_pal).to receive(:list_plans).and_return([['abc'], ['def']])
          get(path)
          metadata = JSON.parse(last_response.body)
          expect(metadata).to eq([{ 'name' => 'abc', 'allowed' => true }, { 'name' => 'def', 'allowed' => false }])
        end

        it 'returns 400 if an project_ref not found error is thrown' do
          get(path)
          error = last_response.body
          expect(error).to eq("`project_ref`: /tmp/foo/#{project_ref} does not exist")
          expect(last_response.status).to eq(400)
        end
      end
    end

    describe '/tasks' do
      let(:fake_pal) { instance_double('BoltServer::PE::PAL') }
      let(:path) { "/tasks?environment=production" }

      it 'returns just the list of task names' do
        expect(BoltServer::PE::PAL).to receive(:new).and_return(fake_pal)
        expect(fake_pal).to receive(:list_tasks).and_return([%w[abc abc_description], %w[def def_description]])
        get(path)
        metadata = JSON.parse(last_response.body)
        expect(metadata).to eq([{ 'name' => 'abc' }, { 'name' => 'def' }])
      end

      it 'returns 400 if an environment not found error is thrown' do
        stub_const("Puppet::Environments::EnvironmentNotFound", StandardError)
        expect(BoltServer::PE::PAL).to receive(:new).and_raise(Puppet::Environments::EnvironmentNotFound)
        get(path)
        expect(last_response.status).to eq(400)
      end
    end

    describe '/project_tasks' do
      let(:fake_pal) { instance_double('Bolt::PAL') }
      let(:fake_project) { instance_double('Bolt::Project') }
      let(:fake_config) { instance_double('Bolt::Config') }
      let(:project_ref) { 'my_project_somesha' }
      let(:path) { "/project_tasks?project_ref=#{project_ref}" }

      before(:each) do
        allow(Bolt::Project).to receive(:create_project).and_return(fake_project)
        allow(Bolt::Config).to receive(:from_project).and_return(fake_config)
        allow(fake_config).to receive(:modulepath)
        allow(fake_config).to receive(:project).and_return(fake_project)
        allow(Bolt::PAL).to receive(:new).and_return(fake_pal)
      end

      it 'returns just the list of task names' do
        allow(Dir).to receive(:exist?).with("/tmp/foo/#{project_ref}").and_return(true)
        allow(fake_project).to receive(:tasks)
        expect(fake_pal).to receive(:list_tasks).and_return([%w[abc abc_description], %w[def def_description]])
        get(path)
        metadata = JSON.parse(last_response.body)
        expect(metadata).to eq([{ 'name' => 'abc', 'allowed' => true }, { 'name' => 'def', 'allowed' => true }])
      end

      it 'returns just the list of task names filtered on project allowlist' do
        allow(Dir).to receive(:exist?).with("/tmp/foo/#{project_ref}").and_return(true)
        allow(fake_project).to receive(:tasks).and_return(['abc'])
        expect(fake_pal).to receive(:list_tasks).and_return([%w[abc abc_description], %w[def def_description]])
        get(path)
        metadata = JSON.parse(last_response.body)
        expect(metadata).to eq([{ 'name' => 'abc', 'allowed' => true }, { 'name' => 'def', 'allowed' => false }])
      end

      it 'returns 400 if an environment not found error is thrown' do
        get(path)
        error = last_response.body
        expect(error).to eq("`project_ref`: /tmp/foo/#{project_ref} does not exist")
        expect(last_response.status).to eq(400)
      end
    end

    describe '/tasks/:module_name/:task_name' do
      let(:fake_pal) { instance_double('BoltServer::PE::PAL') }

      context 'with module_name::task_name' do
        let(:path) { '/tasks/foo/bar?environment=production' }
        let(:mock_task) {
          Bolt::Task.new(task_name, {}, [{ 'name' => 'bar.rb', 'path' => File.expand_path(__FILE__) }])
        }
        let(:task_name) { 'foo::bar' }
        let(:expected_response) {
          {
            "metadata" => {},
            "name" => "foo::bar",
            "files" => [
              {
                "filename" => "bar.rb",
                "sha256" => Digest::SHA256.hexdigest(File.read(__FILE__)),
                "size_bytes" => File.size(__FILE__),
                "uri" => {
                  "path" => "/puppet/v3/file_content/tasks/foo/bar.rb",
                  "params" => { "environment" => "production" }
                }
              }
            ]
          }
        }
        it '/tasks/:module_name/:task_name handles module::task_name' do
          expect(BoltServer::PE::PAL).to receive(:new).and_return(fake_pal)
          expect(fake_pal).to receive(:get_task).with(task_name).and_return(mock_task)
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with module_name' do
        let(:path) { '/tasks/foo/init?environment=production' }
        let(:mock_task) {
          Bolt::Task.new(task_name, {}, [{ 'name' => 'init.rb', 'path' => File.expand_path(__FILE__) }])
        }
        let(:task_name) { 'foo' }
        let(:expected_response) {
          {
            "metadata" => {},
            "name" => "foo",
            "files" => [
              {
                "filename" => "init.rb",
                "sha256" => Digest::SHA256.hexdigest(File.read(__FILE__)),
                "size_bytes" => File.size(__FILE__),
                "uri" => {
                  "path" => "/puppet/v3/file_content/tasks/foo/init.rb",
                  "params" => { "environment" => "production" }
                }
              }
            ]
          }
        }

        it '/tasks/:module_name/:task_name handles task name = module name (init.rb) task' do
          expect(BoltServer::PE::PAL).to receive(:new).and_return(fake_pal)
          expect(fake_pal).to receive(:get_task).with(task_name).and_return(mock_task)
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with non-existant task' do
        let(:path) { '/tasks/foo/bar?environment=production' }
        it 'returns 400 if an unknown plan error is thrown' do
          expect(BoltServer::PE::PAL).to receive(:new).and_return(fake_pal)
          expect(fake_pal).to receive(:get_task).with('foo::bar').and_raise(Bolt::Error.unknown_task('foo::bar'))
          get(path)
          expect(last_response.status).to eq(400)
        end
      end
    end

    describe '/project_tasks/:module_name/:task_name' do
      let(:fake_pal) { instance_double('Bolt::PAL') }
      let(:fake_project) { instance_double('Bolt::Project') }
      let(:fake_config) { instance_double('Bolt::Config') }
      let(:project_ref) { 'my_project_somesha' }

      before(:each) do
        allow(Dir).to receive(:exist?).with("/tmp/foo/#{project_ref}").and_return(true)
        allow(Bolt::Project).to receive(:create_project).and_return(fake_project)
        allow(Bolt::Config).to receive(:from_project).and_return(fake_config)
        allow(fake_config).to receive(:modulepath)
        allow(fake_config).to receive(:project).and_return(fake_project)
        allow(Bolt::PAL).to receive(:new).and_return(fake_pal)
      end

      context 'with module_name::task_name' do
        let(:path) { "/project_tasks/foo/bar?project_ref=#{project_ref}" }
        let(:mock_task) {
          Bolt::Task.new(task_name, {}, [{ 'name' => 'bar.rb', 'path' => File.expand_path(__FILE__) }])
        }
        let(:task_name) { 'foo::bar' }
        let(:expected_response) {
          {
            "metadata" => {},
            "name" => "foo::bar",
            "files" => [
              {
                "filename" => "bar.rb",
                "sha256" => Digest::SHA256.hexdigest(File.read(__FILE__)),
                "size_bytes" => File.size(__FILE__),
                "uri" => {
                  "path" => "/puppet/v3/file_content/tasks/foo/bar.rb",
                  "params" => { "project" => project_ref }
                }
              }
            ],
            "allowed" => true
          }
        }
        it '/project_tasks/:module_name/:task_name handles module::task_name' do
          allow(fake_project).to receive(:tasks)
          expect(fake_pal).to receive(:get_task).with(task_name).and_return(mock_task)
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with module_name' do
        let(:path) { "/project_tasks/foo/init?project_ref=#{project_ref}" }
        let(:mock_task) {
          Bolt::Task.new(task_name, {}, [{ 'name' => 'init.rb', 'path' => File.expand_path(__FILE__) }])
        }
        let(:task_name) { 'foo' }
        let(:expected_response) {
          {
            "metadata" => {},
            "name" => "foo",
            "files" => [
              {
                "filename" => "init.rb",
                "sha256" => Digest::SHA256.hexdigest(File.read(__FILE__)),
                "size_bytes" => File.size(__FILE__),
                "uri" => {
                  "path" => "/puppet/v3/file_content/tasks/foo/init.rb",
                  "params" => { "project" => project_ref }
                }
              }
            ],
            "allowed" => true
          }
        }

        it '/prject_tasks/:module_name/:task_name handles task name = module name (init.rb) task' do
          allow(fake_project).to receive(:tasks)
          expect(fake_pal).to receive(:get_task).with(task_name).and_return(mock_task)
          get(path)
          resp = JSON.parse(last_response.body)
          expect(resp).to eq(expected_response)
        end
      end

      context 'with non-existant task' do
        let(:path) { "/project_tasks/foo/bar?project_ref=#{project_ref}" }
        it 'returns 400 if an unknown plan error is thrown' do
          expect(fake_pal).to receive(:get_task).with('foo::bar').and_raise(Bolt::Error.unknown_task('foo::bar'))
          get(path)
          expect(last_response.status).to eq(400)
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
  end
end
