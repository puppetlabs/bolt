# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'bolt_spec/files'
require 'bolt_spec/integration'
require 'bolt_spec/project'

describe "CLI parses input" do
  include BoltSpec::Conn
  include BoltSpec::Files
  include BoltSpec::Integration
  include BoltSpec::Project

  let(:modulepath)  { fixtures_path('modules') }
  let(:target)      { 'localhost' }
  let(:flags)       { %W[-t #{target} --project #{@project.path}] }
  let(:config)      { { 'modulepath' => [modulepath] } }

  around :each do |example|
    with_project(config: config) do |project|
      @project = project
      example.run
    end
  end

  def get_stdout(result_set)
    result_set.first['value']['stdout'].chomp
  end

  describe "running scripts from the commandline" do
    context 'with future.file_paths enabled' do
      let(:config) do
        { 'modulepath' => [modulepath],
          'future' => { 'file_paths' => true } }
      end

      context 'with nonspecific module syntax' do
        it 'does not load from scripts/ subdir' do
          expect { run_one_node(%w[script run with_scripts/filepath.rb] + flags) }
            .to raise_error(/The script.*with_scripts.*filepath\.rb' does not exist/)
        end

        it 'loads from files/' do
          result = run_one_node(%w[script run with_files/filepath.rb] + flags)
          expect(result['stdout'].chomp).to eq("Loaded from with_files/files/")
        end
      end

      context 'with scripts/ specified' do
        it 'prefers loading from files/scripts/' do
          result = run_one_node(%w[script run with_both/scripts/filepath.rb] + flags)
          expect(result['stdout'].chomp).to eq("Loaded from with_both/files/scripts/")
        end

        it 'falls back to scripts/ if not found in files/' do
          result = run_one_node(%w[script run with_scripts/scripts/filepath.rb] + flags)
          expect(result['stdout'].chomp).to eq("Loaded from with_scripts/scripts/")
        end
      end

      context 'with files/ specified' do
        it 'prefers loading from files/files/' do
          result = run_one_node(%w[script run with_files/files/filepath.rb] + flags)
          expect(result['stdout'].chomp).to eq("Loaded from with_files/files/files/")
        end

        it 'falls back to files/ if enabled' do
          result = run_one_node(%w[script run with_files/files/toplevel.rb] + flags)
          expect(result['stdout'].chomp).to eq("Loaded from with_files/files/")
        end
      end
    end

    context 'with future.file_paths explicitly disabled' do
      it 'does not load from scripts/' do
        expect { run_one_node(%w[script run with_scripts/scripts/filepath.rb] + flags) }
          .to raise_error(%r{The script.*with_scripts/files/scripts/filepath\.rb' does not exist})
      end

      it 'does not load from files/ if files/files/script.rb is specified' do
        expect { run_one_node(%w[script run with_files/files/toplevel.rb] + flags) }
          .to raise_error(%r{The script.*with_files/files/files/toplevel\.rb' does not exist})
      end
    end
  end

  describe "running a plan with run_script()" do
    context 'with future.file_paths enabled' do
      let(:config) do
        { 'modulepath' => [modulepath],
          'future' => { 'file_paths' => true } }
      end

      context 'with nonspecific module syntax' do
        it 'does not load from scripts/ subdir' do
          result = run_cli_json(%w[plan run sample::run_script script=with_scripts/filepath.rb] + flags)
          expect(result['msg'].chomp).to match(%r{No such file or directory: with_scripts/filepath.rb})
        end

        it 'loads from files/' do
          result = run_cli_json(%w[plan run sample::run_script script=with_files/filepath.rb] + flags)
          expect(get_stdout(result)).to eq("Loaded from with_files/files/")
        end
      end

      context 'with scripts/ specified' do
        it 'prefers loading from files/scripts/' do
          result = run_cli_json(%w[plan run sample::run_script script=with_both/scripts/filepath.rb] + flags)
          expect(get_stdout(result)).to eq("Loaded from with_both/files/scripts/")
        end

        it 'falls back to scripts/ if not found in files/' do
          result = run_cli_json(%w[plan run sample::run_script script=with_scripts/scripts/filepath.rb] + flags)
          expect(get_stdout(result)).to eq("Loaded from with_scripts/scripts/")
        end
      end

      context 'with files/ specified' do
        it 'prefers loading from files/files/' do
          result = run_cli_json(%w[plan run sample::run_script script=with_files/files/filepath.rb] + flags)
          expect(get_stdout(result)).to eq("Loaded from with_files/files/files/")
        end

        it 'falls back to files/ if enabled' do
          result = run_cli_json(%w[plan run sample::run_script script=with_files/files/toplevel.rb] + flags)
          expect(get_stdout(result)).to eq("Loaded from with_files/files/")
        end
      end
    end

    context 'with future.file_paths explicitly disabled' do
      it 'does not load from scripts/' do
        result = run_cli_json(%w[plan run sample::run_script script=with_scripts/scripts/filepath.rb] + flags)
        expect(result['msg'].chomp).to match(%r{No such file or directory: with_scripts/scripts/filepath\.rb})
      end

      it 'does not load from files/ if files/files/script.rb is specified' do
        result = run_cli_json(%w[plan run sample::run_script script=with_files/files/toplevel.rb] + flags)
        expect(result['msg'].chomp).to match(%r{No such file or directory: with_files/files/toplevel\.rb})
      end
    end
  end
end
