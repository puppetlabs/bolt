# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

describe 'dir::children' do
  include PuppetlabsSpec::Fixtures
  let(:path) { fixtures('modules', 'test') }

  around(:each) do |example|
    Puppet[:tasks] = true
    project = Struct.new(:name, :path, :load_as_module?).new('default', File.expand_path(path), true)

    Puppet.override(bolt_project: project) do
      example.run
    end
  end

  context 'finding an absolute path' do
    let(:abs_path) { File.expand_path(File.join(path, 'facts.d')) }
    it {
      is_expected.to run.with_params(abs_path).and_return(%w[.hidden fact.py two.sh])
    }
  end

  context 'finding a relative path' do
    it {
      # This is relative to the project directory
      is_expected.to run.with_params('facts.d').and_return(%w[.hidden fact.py two.sh])
    }
  end

  context 'finding a puppet module' do
    it {
      is_expected.to run.with_params('test/facts.d').and_return(%w[.hidden fact.py two.sh])
    }
  end
end
