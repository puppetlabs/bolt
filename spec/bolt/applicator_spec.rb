# frozen_string_literal: true

require 'spec_helper'
require 'bolt/applicator'
require 'bolt/executor'
require 'bolt/inventory'
require 'bolt/pal'
require 'bolt/puppetdb'
require 'bolt/target'

describe Bolt::Applicator do
  let(:uri) { 'foobar' }
  let(:target) { Bolt::Target.new(uri) }
  let(:inventory) { Bolt::Inventory.new(nil) }
  let(:executor) { Bolt::Executor.new }
  let(:config) do
    Bolt::PuppetDB::Config.new('server_urls' => 'https://localhost:8081',
                               'cacert' => '/path/to/cacert',
                               'token' => 'token')
  end
  let(:pdb_client) { Bolt::PuppetDB::Client.new(config) }
  let(:modulepath) { [Bolt::PAL::BOLTLIB_PATH, Bolt::PAL::MODULES_PATH] }
  let(:applicator) { Bolt::Applicator.new(inventory, executor, modulepath, [], pdb_client, nil, 2) }
  let(:ast) { { 'resources' => [] } }

  let(:report) {
    {
      'status' => 'unchanged',
      'resource_statuses' => {},
      'metrics' => {}
    }
  }

  let(:input) {
    {
      code_ast: ast,
      modulepath: modulepath,
      pdb_config: config.to_hash,
      hiera_config: nil,
      target: {
        name: uri,
        facts: { 'bolt' => true },
        variables: {},
        trusted: {
          authenticated: 'local',
          certname: uri,
          extensions: {},
          hostname: uri,
          domain: nil,
          external: {}
        }
      },
      inventory: {
        data: {},
        target_hash: {
          target_vars: {},
          target_facts: {},
          target_features: {}
        },
        config: {
          transport: 'ssh',
          transports: {
            ssh: {
              'connect-timeout' => 10,
              'tty' => false,
              'load-config' => true,
              'disconnect-timeout' => 5
            },
            winrm: { 'connect-timeout' => 10, ssl: true, 'ssl-verify' => true, 'file-protocol' => 'winrm' },
            pcp: {
              'task-environment' => 'production'
            },
            local: {},
            docker: {},
            remote: { 'run-on': 'localhost' }
          }
        }
      }
    }
  }

  it 'instantiates' do
    expect(applicator).to be
  end

  it 'passes catalog input' do
    expect(Open3).to receive(:capture3)
      .with('ruby', /bolt_catalog/, 'compile', stdin_data: input.to_json)
      .and_return(['{}', '', double(:status, success?: true)])
    expect(applicator.compile(target, ast, {})).to eq({})
  end

  it 'logs messages returned on stderr' do
    logs = [
      { debug: 'A message' },
      { notice: 'Stuff happened' }
    ]

    expect(Open3).to receive(:capture3)
      .with('ruby', /bolt_catalog/, 'compile', stdin_data: input.to_json)
      .and_return(['{}', logs.map(&:to_json).join("\n"), double(:status, success?: true)])
    expect(applicator.compile(target, ast, {})).to eq({})
    expect(@log_output.readlines).to eq(
      [
        " DEBUG  Bolt::Executor : Started with 1 max thread(s)\n",
        " DEBUG  Bolt::Applicator : #{target.uri}: A message\n",
        "NOTICE  Bolt::Applicator : #{target.uri}: Stuff happened\n"
      ]
    )
  end

  context 'with Puppet mocked' do
    before(:each) do
      allow(scope).to receive(:to_hash).and_return({})
      env = Puppet::Node::Environment.create(:testing, modulepath)
      allow(Puppet).to receive(:lookup).with(:pal_script_compiler).and_return(double(:script_compiler, type: nil))
      allow(Puppet).to receive(:lookup).with(:current_environment).and_return(env)
      allow(Puppet::Pal).to receive(:assert_type)
      allow(Puppet::Pops::Serialization::ToDataConverter).to receive(:convert).and_return(ast)
      allow(applicator).to receive(:count_statements)
    end

    let(:scope) { double('scope') }

    it 'replaces failures to find Puppet' do
      expect(applicator).to receive(:compile).and_return(ast)
      result = Bolt::Result.new(target, value: report)
      allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task).and_return(result)

      expect(Bolt::ApplyResult).to receive(:puppet_missing_error).with(result).and_return(nil)

      applicator.apply([target], :body, scope)
    end

    it 'captures compile errors in a result set' do
      expect(applicator).to receive(:compile).and_raise('Something weird happened')

      resultset = applicator.apply([uri, '_catch_errors' => true], :body, scope)
      expect(resultset).to be_a(Bolt::ResultSet)
      expect(resultset).not_to be_ok
      expect(resultset.count).to eq(1)
      expect(resultset.first).not_to be_ok
      expect(resultset.first.error_hash['msg']).to eq('Something weird happened')
    end

    it 'fails if the report signals failure' do
      expect(applicator).to receive(:compile).and_return(ast)
      allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task).and_return(
        Bolt::Result.new(target, value: report.merge('status' => 'failed'))
      )

      resultset = applicator.apply([target, '_catch_errors' => true], :body, scope)
      expect(resultset).to be_a(Bolt::ResultSet)
      expect(resultset).not_to be_ok
      expect(resultset.count).to eq(1)
      expect(resultset.first).not_to be_ok
      expect(resultset.first.error_hash['msg']).to match(/Resources failed to apply for #{uri}/)
    end

    it 'includes failed resource events for all failing nodes when errored' do
      resources = {
        '/tmp/does/not/exist' => [{ 'status' => 'failure', 'message' => 'It failed.' }],
        'C:/does/not/exist' => [{ 'status' => 'failure', 'message' => 'It failed.' }],
        '/tmp/sure' => []
      }.map { |name, events| { "File[#{name}]" => { 'failed' => !events.empty?, 'events' => events } } }

      targets = [Bolt::Target.new('node1'), Bolt::Target.new('node2'), Bolt::Target.new('node3')]
      results = targets.zip(resources, %w[failed failed success]).map do |target, res, status|
        Bolt::Result.new(target, value: { 'status' => status, 'resource_statuses' => res, 'metrics' => {} })
      end

      allow(applicator).to receive(:compile).and_return(ast)
      allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task).and_return(*results)

      expect {
        applicator.apply([targets], :body, scope)
      }.to raise_error(Bolt::ApplyFailure, <<~MSG.chomp)
        Resources failed to apply for node1
          File[/tmp/does/not/exist]: It failed.
        Resources failed to apply for node2
          File[C:/does/not/exist]: It failed.
      MSG
    end

    it "only creates 2 threads" do
      running = Concurrent::AtomicFixnum.new
      promises = Concurrent::Array.new
      allow(applicator).to receive(:compile) do
        count = running.increment
        if count <= 2
          # Only first two will block, simplifying cleanup at the end
          delay = Concurrent::Promise.new { ast }
          promises << delay
          delay.value
        else
          ast
        end
      end

      targets = [Bolt::Target.new('node1'), Bolt::Target.new('node2'), Bolt::Target.new('node3')]
      allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task) do |_, batch|
        Bolt::Result.new(batch.first, value: report)
      end

      t = Thread.new {
        applicator.apply([targets], :body, scope)
      }
      sleep(0.2)

      expect(running.value).to eq(2)

      # execute all the promises to release the threads
      expect(promises.count).to eq(2)
      promises.each(&:execute)
      t.join
    end
  end

  context "with future true" do
    let(:input) {
      {
        code_ast: ast,
        modulepath: modulepath,
        pdb_config: config.to_hash,
        hiera_config: nil,
        future: true
      }
    }

    let(:target_hash) {
      {
        target: {
          name: uri,
          facts: { 'bolt' => true },
          variables: {},
          trusted: {
            authenticated: 'local',
            certname: uri,
            extensions: {},
            hostname: uri,
            domain: nil,
            external: {}
          }
        }
      }
    }

    before(:each) do
      # rubocop:disable Style/GlobalVars
      $future = true
      # rubocop:enable Style/GlobalVars
    end

    after(:each) do
      # rubocop:disable Style/GlobalVars
      $future = nil
      # rubocop:enable Style/GlobalVars
    end

    it 'instantiates' do
      expect(applicator).to be
    end

    it 'passes catalog input' do
      expect(Open3).to receive(:capture3)
        .with('ruby', /bolt_catalog/, 'compile', stdin_data: input.merge(target_hash).to_json)
        .and_return(['{}', '', double(:status, success?: true)])
      expect(applicator.future_compile(target, input)).to eq({})
    end

    it 'logs messages returned on stderr' do
      logs = [
        { debug: 'A message' },
        { notice: 'Stuff happened' }
      ]

      expect(Open3).to receive(:capture3)
        .with('ruby', /bolt_catalog/, 'compile', stdin_data: input.merge(target_hash).to_json)
        .and_return(['{}', logs.map(&:to_json).join("\n"), double(:status, success?: true)])
      expect(applicator.future_compile(target, input)).to eq({})
      expect(@log_output.readlines).to eq(
        [
          " DEBUG  Bolt::Executor : Started with 1 max thread(s)\n",
          " DEBUG  Bolt::Applicator : #{target.uri}: A message\n",
          "NOTICE  Bolt::Applicator : #{target.uri}: Stuff happened\n"
        ]
      )
    end

    context 'with Puppet mocked' do
      let(:loaders) { double('loaders') }
      let(:env_loader) { double('env_loader') }
      before(:each) do
        env = Puppet::Node::Environment.create(:testing, modulepath)
        allow(Puppet).to receive(:lookup).with(:current_environment).and_return(env)
        allow(scope).to receive(:to_hash).and_return({})
        allow(Puppet).to receive(:lookup).with(:pal_script_compiler).and_return(double(:script_compiler, type: nil))
        allow(Puppet).to receive(:lookup).with(:loaders).and_return(loaders)
        allow(loaders).to receive(:private_environment_loader).and_return(env_loader)
        allow(env_loader).to receive(:load).with(:type, 'result').and_return(double('result'))
        allow(env_loader).to receive(:load).with(:type, 'resultset').and_return(double('resultset'))
        allow(env_loader).to receive(:load).with(:type, 'applyresult').and_return(double('applyresult'))
        allow(Puppet::Pal).to receive(:assert_type)
        allow(Puppet::Pops::Serialization::ToDataConverter).to receive(:convert).and_return(ast)
        allow(applicator).to receive(:count_statements)
      end

      let(:scope) { double('scope') }

      it 'replaces failures to find Puppet' do
        expect(applicator).to receive(:future_compile).and_return(ast)
        result = Bolt::Result.new(target, value: report)
        allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task).and_return(result)

        expect(Bolt::ApplyResult).to receive(:puppet_missing_error).with(result).and_return(nil)

        applicator.apply([target], :body, scope)
      end

      it 'captures compile errors in a result set' do
        expect(applicator).to receive(:future_compile).and_raise('Something weird happened')

        resultset = applicator.apply([uri, '_catch_errors' => true], :body, scope)
        expect(resultset).to be_a(Bolt::ResultSet)
        expect(resultset).not_to be_ok
        expect(resultset.count).to eq(1)
        expect(resultset.first).not_to be_ok
        expect(resultset.first.error_hash['msg']).to eq('Something weird happened')
      end

      it 'fails if the report signals failure' do
        expect(applicator).to receive(:future_compile).and_return(ast)
        allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task).and_return(
          Bolt::Result.new(target, value: report.merge('status' => 'failed'))
        )

        resultset = applicator.apply([target, '_catch_errors' => true], :body, scope)
        expect(resultset).to be_a(Bolt::ResultSet)
        expect(resultset).not_to be_ok
        expect(resultset.count).to eq(1)
        expect(resultset.first).not_to be_ok
        expect(resultset.first.error_hash['msg']).to match(/Resources failed to apply for #{uri}/)
      end

      it 'includes failed resource events for all failing nodes when errored' do
        resources = {
          '/tmp/does/not/exist' => [{ 'status' => 'failure', 'message' => 'It failed.' }],
          'C:/does/not/exist' => [{ 'status' => 'failure', 'message' => 'It failed.' }],
          '/tmp/sure' => []
        }.map { |name, events| { "File[#{name}]" => { 'failed' => !events.empty?, 'events' => events } } }

        targets = [Bolt::Target.new('node1'), Bolt::Target.new('node2'), Bolt::Target.new('node3')]
        results = targets.zip(resources, %w[failed failed success]).map do |target, res, status|
          Bolt::Result.new(target, value: { 'status' => status, 'resource_statuses' => res, 'metrics' => {} })
        end

        allow(applicator).to receive(:future_compile).and_return(ast)
        allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task).and_return(*results)

        expect {
          applicator.apply([targets], :body, scope)
        }.to raise_error(Bolt::ApplyFailure, <<~MSG.chomp)
          Resources failed to apply for node1
            File[/tmp/does/not/exist]: It failed.
          Resources failed to apply for node2
            File[C:/does/not/exist]: It failed.
        MSG
      end

      it "only creates 2 threads" do
        running = Concurrent::AtomicFixnum.new
        promises = Concurrent::Array.new
        allow(applicator).to receive(:future_compile) do
          count = running.increment
          if count <= 2
            # Only first two will block, simplifying cleanup at the end
            delay = Concurrent::Promise.new { ast }
            promises << delay
            delay.value
          else
            ast
          end
        end

        targets = [Bolt::Target.new('node1'), Bolt::Target.new('node2'), Bolt::Target.new('node3')]
        allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task) do |_, batch|
          Bolt::Result.new(batch.first, value: report)
        end

        t = Thread.new {
          applicator.apply([targets], :body, scope)
        }
        sleep(0.2)

        expect(running.value).to eq(2)

        # execute all the promises to release the threads
        expect(promises.count).to eq(2)
        promises.each(&:execute)
        t.join
      end
    end
  end
end
