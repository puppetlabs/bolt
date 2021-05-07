# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'bolt/executor'

describe 'file::write' do
  let(:executor) { Bolt::Executor.new }

  around(:each) do |example|
    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  it 'writes a file' do
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'file_write')
      is_expected.to run.with_params(file, 'some content')
      expect(File.read(file)).to eq('some content')
    end
  end

  it 'errors in noop mode' do
    executor.expects(:noop).returns(true)

    Dir.mktmpdir do |dir|
      file = File.join(dir, 'file_write')

      is_expected.to run
        .with_params(file, 'some content')
        .and_raise_error(Bolt::Error, /file::write is not supported in noop mode/)
    end
  end
end
