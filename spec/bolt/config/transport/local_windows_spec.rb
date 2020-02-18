# frozen_string_literal: true

require 'spec_helper'
require 'bolt/config/transport/local_windows'
require 'shared_examples/transport_config'

describe Bolt::Config::LocalWindows do
  let(:transport) { Bolt::Config::LocalWindows }
  let(:data) { { 'tmpdir' => '/path/to/tmpdir' } }
  let(:merge_data) { { 'tmpdir' => '/path/to/other/tmpdir' } }

  include_examples 'transport config'
  include_examples 'filters options'

  context 'using plugins' do
    let(:plugin_data) { { 'tmpdir' => { '_plugin' => 'foo' } } }

    include_examples 'plugins'
  end

  context 'validating' do
    include_examples 'interpreters'

    it 'tmpdir errors with wrong type' do
      data['tmpdir'] = ['/path/to/tmpdir']
      expect { transport.new(data) }.to raise_error(Bolt::ValidationError)
    end
  end
end
