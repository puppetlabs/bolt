# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

describe 'file::exists' do
  it {
    Tempfile.open('file_exists') do |file|
      file.write('some content')
      file.flush
      is_expected.to run.with_params(file.path).and_return(true)
    end
  }
end
