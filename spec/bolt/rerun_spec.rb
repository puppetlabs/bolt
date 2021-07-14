# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/files'
require 'bolt_spec/project'
require 'bolt_spec/task'
require 'bolt/cli'
require 'bolt/util'

# This is primarily a test of the cli but cli_spec is over 2k lines so I'm
# keeping this separate.
describe 'rerun' do
  include BoltSpec::Project

  around(:each) do |example|
    with_project(config: config) do |project|
      @project = project
      example.run
    end
  end

  let(:config)      { {} }
  let(:executor)    { double('executor', noop: false, subscribe: nil, shutdown: nil, publish_event: nil) }
  let(:pal)         { double('pal').as_null_object }
  let(:target_spec) { %w[node1 node2] }
  let(:targets)     { target_spec.map { |uri| Bolt::Target.new(uri) } }
  let(:result_vals) { [{}, { '_error' => {} }] }

  let(:result_set) do
    results = targets.zip(result_vals).map do |t, r|
      Bolt::Result.new(t, value: r)
    end
    Bolt::ResultSet.new(results)
  end

  let(:failure_array) do
    result_set.map do |r|
      r = r.to_data
      { 'target' => r['target'], 'status' => r['status'] }
    end
  end

  let(:output) { StringIO.new }

  before(:each) do
    allow($stdout).to receive(:puts)
    allow($stderr).to receive(:puts)

    allow(Bolt::Project).to receive(:find_boltdir).and_return(@project)
    allow(Bolt::Executor).to receive(:new).and_return(executor)
    allow(Bolt::PAL).to receive(:new).and_return(pal)

    # Don't allow tests to override the captured log config
    allow(Bolt::Logger).to receive(:configure)
    allow_any_instance_of(Bolt::CLI).to receive(:warn)
    outputter = Bolt::Outputter::JSON.new(false, false, false, false, output)
    allow_any_instance_of(Bolt::CLI).to receive(:outputter).and_return(outputter)
  end

  def write_rerun(data)
    File.write(File.join(@project.path, '.rerun.json'), data.to_json)
  end

  def read_rerun
    JSON.parse(File.read(File.join(@project.path, '.rerun.json')))
  end

  def run_cli(args)
    cli = Bolt::CLI.new(args)
    cli.execute(cli.parse)
  end

  it 'fails when there is no rerun file' do
    expect do
      run_cli(['command', 'run', 'whoami', '--rerun', 'all'])
    end.to raise_error(Bolt::FileError, /Could not read rerun/)
  end

  it 'fails with an unparsable rerun file' do
    File.write(File.join(@project.path, '.rerun.json'), 'not"json:')
    expect do
      run_cli(['command', 'run', 'whoami', '--rerun', 'all'])
    end.to raise_error(Bolt::FileError, /Unable to parse rerun file/)
  end

  it 'fails with invalid data in the rerun file' do
    write_rerun([{}])
    expect do
      run_cli(['command', 'run', 'whoami', '--rerun', 'all'])
    end.to raise_error(Bolt::FileError, /Missing data in rerun/)
  end

  context 'with a rerun file' do
    before(:each) { write_rerun(failure_array) }

    it 'runs a command with all targets' do
      expect(executor).to receive(:run_command)
        .with(targets, 'whoami', kind_of(Hash))
        .and_return(result_set)
      run_cli(['command', 'run', 'whoami', '--rerun', 'all'])
    end

    it 'runs a command with failed targets' do
      expect(executor).to receive(:run_command)
        .with([targets[1]], 'whoami', kind_of(Hash))
        .and_return(result_set)
      run_cli(['command', 'run', 'whoami', '--rerun', 'failure'])
    end

    it 'runs a command with success targets' do
      expect(executor).to receive(:run_command)
        .with([targets[0]], 'whoami', kind_of(Hash))
        .and_return(result_set)
      run_cli(['command', 'run', 'whoami', '--rerun', 'success'])
    end

    it 'fails with an unhandled filter' do
      expect do
        run_cli(['command', 'run', 'whoami', '--rerun', 'invalid'])
      end.to raise_error(/Unexpected option/)
    end
  end

  context 'with an empty rerun file' do
    before(:each) do
      write_rerun(['original result'])

      allow(executor).to receive(:start_plan)
      allow(executor).to receive(:finish_plan)
      allow(pal).to receive(:parse_params)
      allow(pal).to receive(:parse_manifest)
    end

    let(:success_set) { Bolt::ResultSet.new([result_set.results[0], result_set.results[0]]) }

    it 'updates the file when a command fails' do
      allow(executor).to receive(:run_command)
        .with(targets, 'whoami', kind_of(Hash))
        .and_return(result_set)
      run_cli(['command', 'run', 'whoami', '--targets', target_spec.join(',')])

      expect(read_rerun).to eq(failure_array)
    end

    it 'does not update the file with --no-save-rerun' do
      allow(executor).to receive(:run_command)
        .with(targets, 'whoami', kind_of(Hash))
        .and_return(result_set)
      run_cli(['command', 'run', 'whoami', '--no-tty', '--no-save-rerun', '--targets', target_spec.join(',')])

      expect(read_rerun).to eq(['original result'])
    end

    context 'with save-run: false' do
      let(:config) { { 'save-rerun' => false } }

      it 'does not update the file with save-rerun: false' do
        allow(executor).to receive(:run_command)
          .with(targets, 'whoami', kind_of(Hash))
          .and_return(result_set)
        run_cli(['command', 'run', 'whoami', '--targets', target_spec.join(',')])

        expect(read_rerun).to eq(['original result'])
      end
    end

    it 'updates the file when a plan returns a failing ResultSet' do
      expect(pal).to receive(:run_plan).and_return(Bolt::PlanResult.new(result_set, 'failure'))
      run_cli(%w[plan run whoami])

      expect(read_rerun).to eq(failure_array)
    end

    it 'updates the file when a plan raises a RunFailure' do
      pr = Bolt::PlanResult.new(Bolt::RunFailure.new(result_set, 'failure'), 'command')
      expect(pal).to receive(:run_plan).and_return(pr)
      run_cli(%w[plan run whoami])

      expect(read_rerun).to eq(failure_array)
    end

    it 'deletes the the file when a plan fails with nil' do
      expect(pal).to receive(:run_plan)
        .and_return(Bolt::PlanResult.new(nil, 'failure'))
      run_cli(%w[plan run whoami])

      expect(File.exist?(File.join(@project.path, '.rerun.json'))).to eq(false)
    end

    it 'updates the file when apply fails' do
      allow(pal).to receive(:in_plan_compiler)
      allow(pal).to receive(:with_bolt_executor)
        .and_return(Bolt::ResultSet.new([Bolt::ApplyResult.new(targets[0], error: { 'kind' => 'oops' })]))
      run_cli(['apply', '--targets', 'node1', '-e', 'include foo'])
      expect(read_rerun).to eq([{ "status" => "failure", "target" => "node1" }])
    end

    it 'updates the file when apply succeeds' do
      allow(pal).to receive(:in_plan_compiler)
      allow(pal).to receive(:with_bolt_executor)
        .and_return(Bolt::ResultSet.new([Bolt::ApplyResult.new(targets[0], report: {})]))
      run_cli(['apply', '--targets', 'node1', '-e', 'include foo'])
      expect(read_rerun).to eq([{ "status" => "success", "target" => "node1" }])
    end
  end
end
