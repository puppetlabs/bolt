# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/integration'
require 'bolt_spec/conn'
require 'bolt/util'

shared_examples "invalid metadata" do
  it 'fails with an unknown file' do
    expect {
      run_cli_json(%w[task run shareable::unknown_file] + config_flags)
    }.to raise_error(Bolt::PAL::PALError, %r{Could not find .*shareable/lib/nope on disk})
  end

  it 'fails with an unknown module' do
    expect {
      run_cli_json(%w[task run shareable::unknown_module] + config_flags)
    }.to raise_error(Bolt::PAL::PALError, /Could not find module not_a_module containing task file meh/)
  end

  it 'fails with an invalid path' do
    msg = /Files must be saved in module directories that Puppet makes available via mount points: lib, files, tasks/
    expect {
      run_cli_json(%w[task run shareable::invalid_path] + config_flags)
    }.to raise_error(Bolt::PAL::PALError, msg)
  end

  it 'fails with a file referenced as a directory' do
    msg = if Bolt::Util.windows?
            'Files specified in task metadata cannot include a trailing slash: ' \
            'results/lib/puppet/functions/results/make_result.rb/'
          else
            %r{Could not find .*results/lib/puppet/functions/results/make_result.rb/ on disk}
          end
    expect {
      run_cli_json(%w[task run shareable::not_a_directory] + config_flags)
    }.to raise_error(Bolt::PAL::PALError, msg)
  end

  it 'fails with a directory referenced as a file' do
    msg = %r{Directories specified in task metadata must include a trailing slash: results/lib/puppet}
    expect {
      run_cli_json(%w[task run shareable::not_a_file] + config_flags)
    }.to raise_error(Bolt::PAL::PALError, msg)
  end
end

describe "Shareable tasks with files" do
  include BoltSpec::Integration
  include BoltSpec::Conn

  let(:modulepath) { File.join(__dir__, '../fixtures/modules') }
  let(:config_flags) { %W[--format json --nodes #{target} --modulepath #{modulepath}] + options }

  describe 'over ssh', ssh: true do
    let(:target) { conn_uri('ssh', include_password: true) }
    let(:options) { %w[--no-host-key-check] }

    it 'runs a task with multiple files' do
      result = run_cli_json(%w[task run shareable] + config_flags)
      files = result['items'][0]['result']['_output'].split("\n").map(&:strip).sort
      expect(files.count).to eq(4)
      expect(files[0]).to match(%r{^174 .*/shareable/tasks/unknown_file.json$})
      expect(files[1]).to match(%r{^236 .*/shareable/tasks/list.sh})
      expect(files[2]).to match(%r{^310 .*/results/lib/puppet/functions/results/make_result.rb$})
      expect(files[3]).to match(%r{^43 .*/error/tasks/fail.sh$})
    end

    include_examples "invalid metadata"
  end

  describe 'over winrm', winrm: true do
    let(:target) { conn_uri('winrm') }
    let(:options) { %W[--no-ssl --password #{conn_info('winrm')[:password]}] }

    it 'runs a task with multiple files' do
      result = run_cli_json(%w[task run shareable] + config_flags)
      files = result['items'][0]['result']['_output'].split("\n").map(&:strip).sort
      expect(files).to eq(%w[178 284 310 43])
    end

    include_examples "invalid metadata"
  end

  describe 'over local:bash', bash: true do
    let(:target) { 'localhost' }
    let(:options) { [] }

    it 'runs a task with multiple files' do
      result = run_cli_json(%w[task run shareable] + config_flags)
      files = result['items'][0]['result']['_output'].split("\n").map(&:strip).sort
      expect(files.count).to eq(4)
      expect(files[0]).to match(%r{^174 .*/shareable/tasks/unknown_file.json$})
      expect(files[1]).to match(%r{^236 .*/shareable/tasks/list.sh})
      expect(files[2]).to match(%r{^310 .*/results/lib/puppet/functions/results/make_result.rb$})
      expect(files[3]).to match(%r{^43 .*/error/tasks/fail.sh$})
    end

    include_examples "invalid metadata"
  end
end
