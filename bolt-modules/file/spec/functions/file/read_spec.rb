# frozen_string_literal: true

require 'bolt/executor'
require 'spec_helper'

describe 'file::read' do
  around(:each) do |example|
    Puppet.override({ bolt_executor: executor,
                      future: future }) do
      example.run
    end
  end

  shared_examples 'file loading' do
    let(:future) { {} }

    it 'reads the contents of a file' do
      is_expected.to run.with_params('with_files/toplevel.sh')
                        .and_return("with_files/files/toplevel.sh\n")
    end

    context 'with future.file_paths enabled' do
      let(:future) { { 'file_paths' => true } }

      context 'with nonspecific module syntax' do
        it 'does not load from scripts/ subdir' do
          is_expected.to run
            .with_params('with_scripts/filepath.sh')
            .and_raise_error(/No such file or directory: .*with_scripts.*filepath\.sh/)
        end

        it 'loads from files/' do
          is_expected.to run
            .with_params('with_files/filepath.sh')
            .and_return("with_files/files/filepath.sh\n")
        end
      end

      context 'with scripts/ specified' do
        # filepath.sh is in with_both/files/scripts/ and with_both/scripts/
        it 'prefers loading from files/scripts/' do
          is_expected.to run
            .with_params('with_both/scripts/filepath.sh')
            .and_return("with_both/files/scripts/filepath.sh\n")
        end

        it 'falls back to scripts/ if not found in files/' do
          is_expected.to run
            .with_params('with_scripts/scripts/filepath.sh')
            .and_return("with_scripts/scripts/filepath.sh\n")
        end
      end

      context 'with files/ specified' do
        it 'prefers loading from files/files/' do
          is_expected.to run
            .with_params('with_files/files/filepath.sh')
            .and_return("with_files/files/files/filepath.sh\n")
        end

        it 'falls back to files/ if enabled' do
          is_expected.to run
            .with_params('with_files/files/toplevel.sh')
            .and_return("with_files/files/toplevel.sh\n")
        end
      end
    end

    context 'with future.file_paths explicitly disabled' do
      let(:future) { { 'file_paths' => false } }

      it 'does not load from scripts/' do
        is_expected.to run
          .with_params('with_scripts/scripts/filepath.sh')
          .and_raise_error(/No such file or directory: .*with_scripts.*filepath\.sh/)
      end

      it 'does not load from files/ if files/files/script.sh is specified' do
        # This file exists at the toplevel but not under files/, so should not get loaded
        is_expected.to run
          .with_params('with_files/files/toplevel.sh')
          .and_raise_error(/No such file or directory: .*with_files.*toplevel\.sh/)
      end
    end
  end

  context "with an executor" do
    let(:executor) {
      Bolt::Executor.new(1,
                         Bolt::Analytics::NoopClient.new,
                         false,
                         false,
                         future)
    }

    include_examples 'file loading'
  end

  context "without an executor" do
    let(:executor) { nil }

    include_examples 'file loading'
  end
end
