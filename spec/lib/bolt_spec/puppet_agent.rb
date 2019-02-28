# frozen_string_literal: true

require 'bolt_spec/run'

module BoltSpec
  module PuppetAgent
    include BoltSpec::Run

    def uninstall(target, inventory: nil)
      config = {
        'ssh' => {
          'run-as' => 'root',
          'sudo-password' => conn_info('ssh')[:password],
          'host-key-check' => false
        },
        'winrm' => {
          'ssl' => false
        }
      }
      inventory ||= {}

      uninstall = '/opt/puppetlabs/bin/puppet resource package puppet-agent ensure=absent'
      run_command(uninstall, target, config: config, inventory: inventory)
    end

    def install(target, collection: 'puppet6', inventory: nil)
      config = {
        'ssh' => {
          'run-as' => 'root',
          'sudo-password' => conn_info('ssh')[:password],
          'host-key-check' => false
        },
        'winrm' => {
          'ssl' => false
        }
      }
      inventory ||= {}
      result = run_task('puppet_agent::install', target,
                        { 'collection' => collection },
                        config: config,
                        inventory: inventory)

      expect(result.count).to eq(1)
      expect(result[0]).to include('status' => 'success')
    end
  end
end
