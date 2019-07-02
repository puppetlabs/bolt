# frozen_string_literal: true

require 'spec_helper'
require 'bolt/analytics'
require 'bolt_spec/integration'
require 'bolt_spec/config'
require 'bolt_spec/conn'

describe Bolt::Analytics do
  include BoltSpec::Integration
  include BoltSpec::Config
  include BoltSpec::Conn

  before(:each) do
    @events = []
    @client = Bolt::Analytics::Client.new('test-user')
    allow(@client).to receive(:submit)
    allow(Bolt::Analytics).to receive(:build_client).and_return(@client)
  end

  let(:modulepath) { fixture_path('modules') }

  let(:transport) { Bolt::Util.windows? ? 'winrm' : 'ssh' }
  let(:target) { conn_uri(transport) }
  let(:password) { conn_info(transport)[:password] }

  let(:flags) {
    [
      '--configfile', fixture_path('configs', 'empty.yml'),
      '--modulepath', modulepath,
      '--nodes', target,
      '--password', password,
      '--no-host-key-check',
      '--no-ssl',
      '--no-ssl-verify'
    ]
  }

  def base_params
    @client.base_params
  end

  let(:plan_view) do
    base_params.merge(t: "screenview",
                      cd: "plan_run",
                      cd5: "human",
                      cd4: 1, # target count
                      cd2: 0, # inventory count
                      cd3: 1, # group count
                      cd10: 1, # inventory version
                      cd11: 'option') # boltdir discovery method
  end

  def expect_event(params)
    expect(@client).to receive(:submit).with(base_params.merge(params))
  end

  it 'submits some analytics but not others' do
    expect(@client).to receive(:submit).with(plan_view)
    expect_event(t: "event", ec: "Plan", ea: "call_function", el: "run_task")
    expect_event(t: "event", ec: "Bundled Content", ea: "Task", el: "service")
    expect_event(t: "event", ec: "Transport", ea: "initialize", el: transport, ev: 1)

    expect(@client).not_to receive(:submit).with(hash_including(el: 'identity'))

    run_cli(%w[plan run analytics] + flags)
  end
end
