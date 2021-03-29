# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe 'plans' do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:mpath) { %W[-m #{fixtures_path('modules')}] }

  it 'runs a command in a container' do
    result = run_cli_json(%w[plan run container image=hello-world] + mpath)
    expect(result['value']['stdout']).to include("Hello from Docker!\nThis message shows")
    output = @log_output.readlines
    expect(output).to include(/Starting: run container 'hello-world'/)
    expect(output).to include(/Finished: run container 'hello-world' succeeded./)
  end

  it 'mounts a volume to the container' do
    dest = Bolt::Util.windows? ? 'C:\volume' : '/volume'
    ls = Bolt::Util.windows? ? "powershell -c 'ls'" : 'ls'
    cmd = %W[plan run container::volume ls=#{ls} src=#{File.expand_path('.')} dest=#{dest}]
    cmd << 'image=mcr.microsoft.com/windows/servercore:ltsc2019' if Bolt::Util.windows?
    result = run_cli_json(cmd + mpath)
    expect(result['value']['stdout']).to include("bolt.gemspec")
  end

  it 'serializes ContainerResults to apply blocks', ssh: true do
    with_project(inventory: docker_inventory) do |project|
      flags = %W[--project #{project} -t nix_agents] + mpath
      result = run_cli_json(%w[plan run container::apply] + flags)
      users = result.map do |hash|
        hash.dig('value', 'report', 'resource_statuses').keys
      end.flatten
      expect(users).to eq(["Notify[root\n]", "Notify[root\n]"])
    end
  end
end
