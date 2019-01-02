# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

describe 'file::read' do
  it {
    Tempfile.open('file_read') do |file|
      file.write('some content')
      file.flush
      is_expected.to run.with_params(file.path).and_return('some content')
    end
  }
end
