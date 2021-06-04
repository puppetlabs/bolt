# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'plans' do
  include BoltSpec::Integration
  include BoltSpec::Files
  include BoltSpec::Conn
  include BoltSpec::Project

  after(:each) { Puppet.settings.send(:clear_everything_for_tests) }

  let(:modulepath) { fixtures_path('parallel') }

  shared_examples "parallelize plan function" do
    let(:return_value) {
      { "action" => "task",
        "object" => "parallel",
        "status" => "success",
        "value" => { "_output" => /print/ } }
    }

    it "returns an array of Results" do
      results = run_cli_json(%w[plan run parallel] + config_flags)
      results.each do |result|
        expect(result).to be_a(Array)
        expect(result.length).to eq(1)
        expect(result.first).to include(return_value)
      end
    end

    it "returns from a return statement" do
      before_time = Time.now
      results = run_cli_json(%w[plan run parallel::return] + config_flags)
      wall_time = Time.now - before_time
      # Assert we don't execute the sleep
      expect(wall_time).to be < 2
      results.each do |result|
        expect(result).to eq('a')
      end
    end

    it "does not raise an error when catch_errors wraps the block" do
      result = run_cli_json(%w[plan run parallel::catch_error_outer] + config_flags)
      expect(result).to eq("We made it")
    end

    it "does not raise an error when catch_errors is inside the block" do
      result = run_cli_json(%w[plan run parallel::catch_error_inner] + config_flags)
      expect(result).to eq("We made it")
    end

    it "fails immediately when a Puppet error is raised" do
      expect { run_cli_json(%w[plan run parallel::hard_fail] + config_flags) }
        .to raise_error(Bolt::PAL::PALError, /This Name has no effect./)
    end

    it "runs normally when no steps are parallelizable" do
      result = run_cli_json(%w[plan run parallel::non_parallel] + config_flags)
      expect(result).to eq("Success")
    end

    it "runs when provided an array with duplicate objects" do
    end
  end

  shared_examples "#background()" do
    it "returns a Future object immediately" do
      # CODEREVIEW: Is it worse to have this on one line, or like this? Using
      # Regexp::EXTENDED doesn't work.
      regex = %r{Returned immediately
Type of Future '\d'
Finished: plan background::timing .*
Starting backgrounded block
Plan completed successfully}

      output = run_cli(%w[plan run background::timing] + config_flags,
                       outputter: Bolt::Outputter::Human)
      expect(output).to match(regex)
    end

    it "includes variables, including undef vars, from the plan in scope" do
      regex = %r{Starting: plan background::variables
In main plan: After background
Finished: plan background::variables.*
Inside background: Before background
Undef:}
      output = run_cli(%w[plan run background::variables] + config_flags,
                       outputter: Bolt::Outputter::Human)
      expect(output).to match(regex)
      expect(output).to match(/Unknown variable: 'foo'/)
      expect(output).not_to match(/Unknown variable: 'undef'/)
    end

    it "returns from a 'return' statement'" do
      output = run_cli_json(%w[plan run background::return] + config_flags)
      expect(output.first).to eq("Return me!")
    end

    it "does not fail the plan if errors are raised before main plan finishes" do
      output = run_cli_json(%w[plan run background::error sleep=true] + config_flags)
      expect(output).to eq("Still ran successfully")
      expect(@log_output.readlines).to include(/INFO  Bolt::Executor.*The command failed/)
    end

    it "does not fail the plan if errors are raised after main plan finishes" do
      output = run_cli_json(%w[plan run background::error] + config_flags)
      expect(output).to eq("Still ran successfully")
      expect(@log_output.readlines).to include(/WARN.*run_command 'exit 1' failed/)
    end
  end

  shared_examples "#wait()" do
    context "without a timeout" do
      it 'blocks until all futures have finished' do
        expected = <<~OUT
        [
          "I don't know's on third",
          "What's on second",
          "Who's on first"
        ]
        That's what I want to find out.
        OUT
        output = run_cli(%w[plan run wait] + config_flags, outputter: Bolt::Outputter::Human)
        expect(output).to include(expected)
      end

      it "doesn't include results from futures not passed to the function" do
        expected = <<~OUT
        [
          "What's on second"
        ]
        That's what I want to find out.
        OUT
        output = run_cli(%w[plan run wait start=1 end=1] + config_flags, outputter: Bolt::Outputter::Human)
        expect(output).to include(expected)
      end

      it "doesn't wait for inner Futures to finish" do
        output = run_cli(%w[plan run wait::inner_future] + config_flags, outputter: Bolt::Outputter::Human)
        expect(output).to include("Before inner future\nFinished: plan wait")
      end

      it 'continues if one future errors, and raises a ParallelFailure' do
        output = run_cli(%w[plan run wait::error] + config_flags,
                         outputter: Bolt::Outputter::Human)
        expect(output).to include("Who's on first\nI don't know's on third")
        expect(output).to include("\"msg\": \"Plan aborted: parallel block failed on 1 target")
        expect(output).not_to include("Finished main plan.")
      end

      it 'returns errors if _catch_errors is passed' do
        output = run_cli(%w[plan run wait::error catch_errors=true] + config_flags,
                         outputter: Bolt::Outputter::Human)
        expect(output).to include("Who's on first\nI don't know's on third")
        expect(output).to include("Plan aborted: run_command 'exit 1' failed")
        expect(output).to include("Finished main plan.")
      end
    end

    context "with a timeout" do
      it 'returns once fibers have finished if timeout is longer' do
        start = Time.now
        run_cli(%w[plan run wait::timeout timeout=20] + config_flags)
        expect(Time.now - start).to be < 20
      end

      it 'raises a Timeout error if timeout is exceeded' do
        params = { 'timeout' => 0.1, 'sleep' => 0.5 }.to_json
        output = run_cli_json(%W[plan run wait::timeout --params #{params}] + config_flags)
        expect(output['kind']).to eq("bolt/parallel-failure")
        expect(output['msg']).to match(/Plan aborted: parallel block failed/)
        expect(output['details']).to include({ "action" => "parallelize", "failed_indices" => [1] })
      end

      it 'returns Timeout errors if _catch_errors is provided' do
        params = { 'timeout' => 0.1, 'sleep' => 0.5, 'catch_errors' => true }.to_json
        output = run_cli_json(%W[plan run wait::timeout --params #{params}] + config_flags)
        expect(output).to eq("Finished the plan")
      end
    end
  end

  context "over ssh", ssh: true do
    let(:inv_path)      { fixtures_path('inventory', 'docker.yaml') }
    let(:config_flags)  {
      ['-t all',
       '--modulepath', modulepath,
       '--inventoryfile', inv_path,
       '--verbose',
       '--no-host-key-check']
    }

    include_examples 'parallelize plan function'
    include_examples '#background()'
    include_examples '#wait()'

    it "finishes executing the block then raises an error when there's an error" do
      expected_err = { "kind" => "bolt/parallel-failure",
                       "msg" => "Plan aborted: parallel block failed on 1 target" }
      expected_details = { "action" => "parallelize",
                           "failed_indices" => [1] }
      expected_results = [[{ "target" => 'ubuntu_node',
                             "action" => "task",
                             "object" => "parallel",
                             "status" => "success",
                             "value" => { "_output" => "a\n" } }],
                          { "kind" => "bolt/run-failure",
                            "msg" => "Plan aborted: run_task 'error::fail' failed on 1 target",
                            "details" =>
                          { "action" => "run_task",
                            "object" => "error::fail",
                            "result_set" =>
                          [{ "target" => 'puppet_6_node',
                             "action" => "task",
                             "object" => "error::fail",
                             "status" => "failure",
                             "value" =>
                          { "_output" => "failing\n",
                            "_error" =>
                          { "kind" => "puppetlabs.tasks/task-error",
                            "issue_code" => "TASK_ERROR",
                            "msg" => "The task failed with exit code 1",
                            "details" => {
                              "file" => fixtures_path('parallel', 'parallel', 'plans', 'error.pp'),
                              "line" => 7,
                              "exit_code" => 1
                            } } } }] } }]
      result = run_cli_json(%w[plan run parallel::error] + config_flags)
      expect(result).to include(expected_err)
      expect(result['details']).to include(expected_details)
      expect(expected_results - result['details']['results']).to eq([])
    end
  end

  context "over winrm", winrm: true do
    let(:targets) { conn_uri('winrm') }
    let(:config_flags) {
      ['-t', targets,
       '--modulepath', modulepath,
       '--verbose',
       '--password', conn_info('winrm')[:password],
       '--no-ssl',
       '--no-ssl-verify']
    }

    include_examples 'parallelize plan function'
    include_examples '#background()'
    include_examples '#wait()'
  end
end
