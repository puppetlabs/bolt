# frozen_string_literal: true

require 'bolt/executor'
require 'spec_helper'

describe 'file::readable' do
  around(:each) do |example|
    Puppet.override({ bolt_executor: executor }) do
      example.run
    end
  end

  shared_examples 'file loading' do
    it 'returns if a file is readable' do
      is_expected.to run.with_params('with_files/toplevel.sh').and_return(true)
    end

    context 'when locating files' do
      context 'with nonspecific module syntax' do
        it 'does not load from scripts/ subdir' do
          is_expected.to run
            .with_params('with_scripts/filepath.sh')
            .and_return(false)
        end

        it 'loads from files/' do
          is_expected.to run
            .with_params('with_files/filepath.sh')
            .and_return(true)
        end
      end

      context 'with scripts/ specified' do
        # filepath.sh is in with_both/files/scripts/ and with_both/scripts/
        it 'prefers loading from files/scripts/' do
          is_expected.to run
            .with_params('with_both/scripts/filepath.sh')
            .and_return(true)
        end

        it 'falls back to scripts/ if not found in files/' do
          is_expected.to run
            .with_params('with_scripts/scripts/filepath.sh')
            .and_return(true)
        end
      end

      context 'with files/ specified' do
        it 'prefers loading from files/files/' do
          is_expected.to run
            .with_params('with_files/files/filepath.sh')
            .and_return(true)
        end

        it 'falls back to files/ if enabled' do
          is_expected.to run
            .with_params('with_files/files/toplevel.sh')
            .and_return(true)
        end
      end
    end
  end

  context "with an executor" do
    let(:executor) {
      Bolt::Executor.new(1,
                         Bolt::Analytics::NoopClient.new,
                         false,
                         false)
    }

    include_examples 'file loading'
  end

  context "without an executor" do
    let(:executor) { nil }

    include_examples 'file loading'
  end
end
