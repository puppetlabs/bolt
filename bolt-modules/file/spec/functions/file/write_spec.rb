# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

describe 'file::write' do
  it {
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'file_write')
      is_expected.to run.with_params(file, 'some content')
      expect(File.read(file)).to eq('some content')
    end
  }
end
