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
  let(:target) { inventory.get_target(uri) }
  let(:inventory) { Bolt::Inventory.empty }
  let(:executor) { Bolt::Executor.new }
  let(:config) do
    Bolt::PuppetDB::Config.new('server_urls' => 'https://localhost:8081',
                               'cacert' => '/path/to/cacert',
                               'token' => 'token')
  end
  let(:pdb_client) { Bolt::PuppetDB::Client.new(config) }
  let(:modulepath) { [Bolt::PAL::BOLTLIB_PATH, Bolt::PAL::MODULES_PATH] }
  let(:applicator) { Bolt::Applicator.new(inventory, executor, modulepath, [], nil, pdb_client, nil, 2, {}) }
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
      hiera_config: nil
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

  it 'instantiates' do
    expect(applicator).to be
  end

  it 'errors with an empty catalog' do
    expect { applicator.apply([target], nil, nil) }
      .to raise_error(ArgumentError, /apply requires at least one statement/)
  end

  it 'passes catalog input' do
    expect(Open3).to receive(:capture3)
      .with('ruby', /bolt_catalog/, 'compile', stdin_data: input.merge(target_hash).to_json)
      .and_return(['{}', '', double(:status, success?: true)])
    expect(applicator.compile(target, input)).to eq({})
  end

  it 'logs messages returned on stderr' do
    logs = [
      { level: 'debug', message: 'A message' },
      { level: 'notice', message: 'Stuff happened' }
    ]

    expect(Open3).to receive(:capture3)
      .with('ruby', /bolt_catalog/, 'compile', stdin_data: input.merge(target_hash).to_json)
      .and_return(['{}', logs.map(&:to_json).join("\n"), double(:status, success?: true)])
    expect(applicator.compile(target, input)).to eq({})
    expect(@log_output.readlines).to eq(
      [
        " DEBUG  Bolt::Executor : Started with 1 max thread(s)\n",
        " DEBUG  Bolt::Inventory::Inventory : Did not find config for #{target.uri} in inventory\n",
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
      allow(Puppet).to receive(:lookup).with(:bolt_project).and_return(nil)
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
      expect(resultset.first.error_hash['msg']).to match(/Something weird happened/)
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

    it 'includes failed resource events for all failing targets when errored' do
      resources = {
        '/tmp/does/not/exist' => [{ 'status' => 'failure', 'message' => 'It failed.' }],
        'C:/does/not/exist' => [{ 'status' => 'failure', 'message' => 'It failed.' }],
        '/tmp/sure' => []
      }.map { |name, events| { "File[#{name}]" => { 'failed' => !events.empty?, 'events' => events } } }

      targets = inventory.get_targets(%w[target1 target2 target3])
      results = targets.zip(resources, %w[failed failed success]).map do |target, res, status|
        Bolt::Result.new(target, value: { 'status' => status, 'resource_statuses' => res, 'metrics' => {} })
      end

      allow(applicator).to receive(:compile).and_return(ast)
      allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task).and_return(*results)

      expect {
        applicator.apply([targets], :body, scope)
      }.to raise_error(Bolt::ApplyFailure, <<~MSG.chomp)
        Resources failed to apply for target1
          File[/tmp/does/not/exist]: It failed.
        Resources failed to apply for target2
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

      targets = inventory.get_targets(%w[target1 target2 target3])
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
