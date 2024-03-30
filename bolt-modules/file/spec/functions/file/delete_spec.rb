# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

describe 'file::delete' do
  it {
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'file_delete')
      File.write(file, 'file_delete_contents')
      is_expected.to run.with_params(file)
      expect(File.exist?(file)).to eq(false)
    end
  }
end
