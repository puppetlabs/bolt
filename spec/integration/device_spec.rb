# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'
require 'bolt_spec/run'

describe "devices" do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project
  include BoltSpec::Run

  describe 'over ssh', ssh: true do
    let(:modulepath)  { fixtures_path('apply') }
    let(:device_path) { "/tmp/#{SecureRandom.uuid}.json" }

    let(:device_group) do
      {
        'name' => 'device_targets',
        'targets' => [
          {
            'uri' => 'fake_device1',
            'config' => {
              'transport' => 'remote',
              'remote' => {
                'remote-transport' => 'fake',
                'run-on' => 'puppet_6_node',
                'path' => device_path
              }
            }
          }
        ]
      }
    end

    let(:inventory) do
      inv = docker_inventory(root: true)
      inv['groups'] << device_group
      inv
    end

    let(:config) do
      {
        'modulepath' => modulepath
      }
    end

    around(:each) do |example|
      with_project(config: config, inventory: inventory) do |project|
        @project = project
        example.run
      end
    end

    context "when running against puppet 6" do
      it 'runs a plan that collects facts' do
        results = run_cli_json(%w[plan run device_test::facts -t device_targets], project: @project)

        expect(results).not_to include('kind')

        name, facts = results.first
        expect(name).to eq('fake_device1')
        expect(facts).to include(
          'operatingsystem' => 'FakeDevice',
          'exists'          => false,
          'clientcert'      => 'fake_device1'
        )
      end

      it 'runs a plan that applies resources' do
        results = run_cli_json(%w[plan run device_test::set_a_val -t device_targets], project: @project)

        expect(results).not_to include('kind')
        expect(results.dig(0, 'value', 'report', 'resource_statuses')).to include('Fake_device[key1]')

        content = run_cli_json(['command', 'run', "cat '#{device_path}'", '-t', 'puppet_6_node'], project: @project)

        expect(content.dig('items', 0, 'value', 'stdout')).to eq({ key1: 'val1' }.to_json)

        resources = run_cli_json(%w[plan run device_test::resources -t device_targets], project: @project)

        expect(resources.dig(0, 'value', 'resources', 0)).to eq(
          'key1' => {
            'content' => 'val1',
            'ensure'  => 'present',
            'merge'   => false
          }
        )
      end
    end
  end
end
