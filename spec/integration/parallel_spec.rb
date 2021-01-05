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

  let(:modulepath) { fixtures_path('modules') }

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
  end

  context "over ssh", ssh: true do
    let(:inv_path) { fixtures_path('inventory', 'docker.yaml') }
    let(:config_flags) {
      ['-t all',
       '--modulepath', modulepath,
       '--inventoryfile', inv_path,
       '--verbose',
       '--no-host-key-check']
    }

    include_examples 'parallelize plan function'

    it "finishes executing the block then raises an error when there's an error" do
      expected_err = { "kind" => "bolt/parallel-failure",
                       "msg" => "Plan aborted: parallel block failed on 1 target" }
      expected_details = { "action" => "parallelize",
                           "failed_indices" => [2] }
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
                            "details" => { "exit_code" => 1 } } } }] } }]

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
  end
end
