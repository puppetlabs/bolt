# frozen_string_literal: true

require 'spec_helper'

describe "when loading bolt for CLI invocation" do
  context 'and calling help' do
    def cli_loaded_features
      cli_loader = File.join(__dir__, '..', 'fixtures', 'scripts', 'bolt_cli_loader.rb')
      `bundle exec ruby #{cli_loader}`.split("\n")
    end

    let(:loaded_features) { cli_loaded_features }

    [
      # docker-api + dependencies
      'docker-api',
      'excon',
      # ruby_smb + dependencies
      'ruby_smb',
      'bindata',
      'rubyntlm',
      'windows_error',
      # FFI + dependencies
      'ffi',
      # orchestrator client + dependencies
      'orchestrator_client',
      'faraday',
      'multipart-post',
      # concurrent gem + dependencies
      'concurrent-ruby',
      # httpclient + dependencies
      'httpclient'
    ].each do |gem_name|
      it "does not load #{gem_name} gem code" do
        gem_path = Regexp.escape(Gem.loaded_specs[gem_name].full_gem_path)
        any_gem_source_code = a_string_matching(gem_path)
        fail_msg = "loaded unexpected #{gem_name} gem code from #{gem_path}"
        expect(loaded_features).not_to include(any_gem_source_code), fail_msg
      end
    end

    [
      'openssl/x509.rb'
    ].each do |code_path|
      it "does not load #{code_path}" do
        specific_code = a_string_matching(Regexp.escape(code_path))
        fail_msg = "loaded unexpected #{code_path}"
        expect(loaded_features).not_to include(specific_code), fail_msg
      end
    end
  end
end
