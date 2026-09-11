# frozen_string_literal: true

require 'spec_helper'
require 'bolt/error'
require 'bolt/result'
require 'bolt/result_set'
require 'bolt/inventory'

describe Bolt::Error do
  describe '#initialize' do
    it 'sets kind, details, and message' do
      err = described_class.new('something went wrong', 'bolt/test-error', { 'path' => '/tmp' }, 'ISSUE_1')
      expect(err.message).to eq('something went wrong')
      expect(err.kind).to eq('bolt/test-error')
      expect(err.details).to eq('path' => '/tmp')
      expect(err.issue_code).to eq('ISSUE_1')
    end

    it 'defaults details to empty hash' do
      err = described_class.new('oops', 'bolt/test')
      expect(err.details).to eq({})
    end

    it 'defaults error_code to 1' do
      err = described_class.new('oops', 'bolt/test')
      expect(err.error_code).to eq(1)
    end
  end

  describe '#msg' do
    it 'returns the message' do
      err = described_class.new('hello', 'bolt/test')
      expect(err.msg).to eq('hello')
    end
  end

  describe '#to_h' do
    it 'returns a hash with kind, msg, and details' do
      err = described_class.new('oops', 'bolt/test', { 'x' => 1 })
      h = err.to_h
      expect(h['kind']).to eq('bolt/test')
      expect(h['msg']).to eq('oops')
      expect(h['details']).to eq('x' => 1)
    end

    it 'includes issue_code when present' do
      err = described_class.new('oops', 'bolt/test', {}, 'MY_CODE')
      expect(err.to_h['issue_code']).to eq('MY_CODE')
    end

    it 'omits issue_code when nil' do
      err = described_class.new('oops', 'bolt/test')
      expect(err.to_h).not_to have_key('issue_code')
    end
  end

  describe '#add_filelineno' do
    it 'merges details when file is not already set' do
      err = described_class.new('oops', 'bolt/test')
      err.add_filelineno('file' => '/my/file.rb', 'line' => 42)
      expect(err.details['file']).to eq('/my/file.rb')
    end

    it 'does not overwrite existing file details' do
      err = described_class.new('oops', 'bolt/test', { 'file' => '/original.rb' })
      err.add_filelineno('file' => '/new.rb')
      expect(err.details['file']).to eq('/original.rb')
    end
  end

  describe '#to_json' do
    it 'returns JSON string' do
      err = described_class.new('oops', 'bolt/test')
      parsed = JSON.parse(err.to_json)
      expect(parsed['kind']).to eq('bolt/test')
    end
  end

  describe '.unknown_task' do
    it 'returns error with task name in message' do
      allow(Bolt::Util).to receive(:powershell?).and_return(false)
      err = described_class.unknown_task('my_task')
      expect(err.kind).to eq('bolt/unknown-task')
      expect(err.message).to match(/my_task/)
    end

    it 'references PowerShell command when in PowerShell' do
      allow(Bolt::Util).to receive(:powershell?).and_return(true)
      err = described_class.unknown_task('my_task')
      expect(err.message).to match(/Get-BoltTask/)
    end
  end

  describe '.unknown_plan' do
    it 'returns error with plan name in message' do
      allow(Bolt::Util).to receive(:powershell?).and_return(false)
      err = described_class.unknown_plan('my_plan')
      expect(err.kind).to eq('bolt/unknown-plan')
      expect(err.message).to match(/my_plan/)
    end

    it 'references PowerShell command when in PowerShell' do
      allow(Bolt::Util).to receive(:powershell?).and_return(true)
      err = described_class.unknown_plan('my_plan')
      expect(err.message).to match(/Get-BoltPlan/)
    end
  end
end

describe Bolt::CLIError do
  it 'sets kind to bolt/cli-error' do
    err = described_class.new('bad input')
    expect(err.kind).to eq('bolt/cli-error')
    expect(err.message).to eq('bad input')
  end
end

describe Bolt::ContainerFailure do
  let(:container_result) do
    double('result',
           value: { 'stdout' => 'hi' },
           object: 'myimage:latest')
  end

  it 'creates an error with container details' do
    err = described_class.new(container_result)
    expect(err.kind).to eq('bolt/container-failure')
    expect(err.message).to match(/myimage:latest/)
    expect(err.error_code).to eq(2)
    expect(err.result).to eq(container_result)
  end
end

describe Bolt::RunFailure do
  let(:target) { Bolt::Inventory.empty.get_target('host1') }
  let(:failed_result) { Bolt::Result.new(target, error: { 'msg' => 'oops', 'kind' => 'bolt/err', 'details' => {} }) }
  let(:result_set) { Bolt::ResultSet.new([failed_result]) }

  it 'creates an error with result set info' do
    err = described_class.new(result_set, 'run', 'mytask')
    expect(err.kind).to eq('bolt/run-failure')
    expect(err.message).to match(/mytask/)
    expect(err.error_code).to eq(2)
    expect(err.result_set).to eq(result_set)
  end

  it 'pluralizes targets for multiple failures' do
    target2 = Bolt::Inventory.empty.get_target('host2')
    r2 = Bolt::Result.new(target2, error: { 'msg' => 'oops', 'kind' => 'bolt/err', 'details' => {} })
    rs = Bolt::ResultSet.new([failed_result, r2])
    err = described_class.new(rs, 'run')
    expect(err.message).to match(/targets/)
  end
end

describe Bolt::ApplyFailure do
  let(:target) { Bolt::Inventory.empty.get_target('host1') }
  let(:failed_result) {
    Bolt::Result.new(target, error: { 'msg' => 'compile error', 'kind' => 'bolt/err', 'details' => {} })
  }
  let(:result_set) { Bolt::ResultSet.new([failed_result]) }

  it 'creates an apply failure' do
    err = described_class.new(result_set)
    expect(err.kind).to eq('bolt/apply-failure')
  end

  it 'to_s joins error messages' do
    err = described_class.new(result_set)
    expect(err.to_s).to include('compile error')
  end
end

describe Bolt::FutureTimeoutError do
  it 'creates an error with future name and timeout' do
    err = described_class.new('my_future', 30)
    expect(err.kind).to eq('bolt/future-timeout-error')
    expect(err.message).to match(/my_future/)
    expect(err.message).to match(/30/)
    expect(err.details['future']).to eq('my_future')
  end
end

describe Bolt::ParallelFailure do
  it 'creates an error with failed indices' do
    err = described_class.new(%w[r1 r2], [0, 1])
    expect(err.kind).to eq('bolt/parallel-failure')
    expect(err.error_code).to eq(2)
    expect(err.details['failed_indices']).to eq([0, 1])
  end

  it 'pluralizes for multiple failures' do
    err = described_class.new(%w[r1 r2], [0, 1])
    expect(err.message).to match(/targets/)
  end

  it 'does not pluralize for single failure' do
    err = described_class.new(['r1'], [0])
    expect(err.message).not_to match(/targets/)
  end
end

describe Bolt::PlanFailure do
  it 'sets error_code to 2' do
    err = described_class.new('plan failed', 'bolt/plan-failure')
    expect(err.error_code).to eq(2)
  end
end

describe Bolt::PuppetfileError do
  it 'creates an error with puppetfile message' do
    err = described_class.new('missing module')
    expect(err.kind).to eq('bolt/puppetfile-error')
    expect(err.message).to match(/missing module/)
  end
end

describe Bolt::ApplyError do
  it 'creates an error for failed compilation' do
    err = described_class.new('target1', 'syntax error')
    expect(err.kind).to eq('bolt/apply-error')
    expect(err.message).to match(/target1/)
    expect(err.message).to match(/syntax error/)
  end
end

describe Bolt::ParseError do
  it 'creates a parse error' do
    err = described_class.new('unexpected token')
    expect(err.kind).to eq('bolt/parse-error')
    expect(err.message).to eq('unexpected token')
  end
end

describe Bolt::InvalidPlanResult do
  it 'creates an error with plan name and result string' do
    err = described_class.new('myplan', 'nil')
    expect(err.kind).to eq('bolt/invalid-plan-result')
    expect(err.message).to match(/myplan/)
    expect(err.details['plan_name']).to eq('myplan')
  end
end

describe Bolt::InvalidParallelResult do
  it 'creates an error with file and line' do
    err = described_class.new('nil', '/my/plan.pp', 10)
    expect(err.kind).to eq('bolt/invalid-plan-result')
    expect(err.details['file']).to eq('/my/plan.pp')
    expect(err.details['line']).to eq(10)
  end
end

describe Bolt::ValidationError do
  it 'creates a validation error' do
    err = described_class.new('invalid value')
    expect(err.kind).to eq('bolt/validation-error')
    expect(err.message).to eq('invalid value')
  end
end

describe Bolt::FileError do
  it 'creates a file error with path in details' do
    err = described_class.new('file not found', '/some/path')
    expect(err.kind).to eq('bolt/file-error')
    expect(err.details['path']).to eq('/some/path')
  end
end
