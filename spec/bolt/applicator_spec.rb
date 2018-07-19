# frozen_string_literal: true

require 'spec_helper'
require 'bolt/applicator'
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
  let(:applicator) { Bolt::Applicator.new(inventory, executor, :mod, pdb_client, nil, 2) }

  let(:input) {
    {
      code_ast: :ast,
      modulepath: :mod,
      pdb_config: config.to_hash,
      hiera_config: nil,
      target: {
        name: uri,
        facts: {},
        variables: {},
        trusted: {
          authenticated: 'local',
          certname: uri,
          extensions: {},
          hostname: uri,
          domain: nil
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
    expect(applicator.compile(target, :ast, {})).to eq({})
  end

  it 'logs messages returned on stderr' do
    logs = [
      { debug: 'A message' },
      { notice: 'Stuff happened' }
    ]

    expect(Open3).to receive(:capture3)
      .with('ruby', /bolt_catalog/, 'compile', stdin_data: input.to_json)
      .and_return(['{}', logs.map(&:to_json).join("\n"), double(:status, success?: true)])
    expect(applicator.compile(target, :ast, {})).to eq({})
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
      allow(Puppet).to receive(:lookup).and_return(double(:type, type: nil))
      allow(Puppet::Pal).to receive(:assert_type)
      allow(Puppet::Pops::Serialization::ToDataConverter).to receive(:convert).and_return(:ast)
    end

    it 'captures compile errors in a result set' do
      expect(applicator).to receive(:compile).and_raise('Something weird happened')

      resultset = applicator.apply([uri], :body, {})
      expect(resultset).to be_a(Bolt::ResultSet)
      expect(resultset.count).to eq(1)
      expect(resultset.first.ok).to be(false)
      expect(resultset.first.error_hash['msg']).to eq('Something weird happened')
    end

    it "only creates 2 threads" do
      running = Concurrent::AtomicFixnum.new
      promises = Concurrent::Array.new
      allow(applicator).to receive(:compile) do
        count = running.increment
        if count <= 2
          # Only first two will block, simplifying cleanup at the end
          delay = Concurrent::Promise.new { {} }
          promises << delay
          delay.value
        else
          {}
        end
      end

      targets = [Bolt::Target.new('node1'), Bolt::Target.new('node2'), Bolt::Target.new('node3')]
      results = targets.map { |target| Bolt::Result.new(target) }
      allow_any_instance_of(Bolt::Transport::SSH).to receive(:batch_task).and_return(*results)

      t = Thread.new {
        applicator.apply([targets], :body, {})
      }
      sleep(0.1)

      expect(running.value).to eq(2)

      # execute all the promises to release the threads
      expect(promises.count).to eq(2)
      promises.each(&:execute)
      t.join
    end
  end
end
