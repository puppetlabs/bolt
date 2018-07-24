# frozen_string_literal: true

test_name "Install Puppet Agent" do
  install_puppet_agent_on(hosts, puppet_collection: 'puppet5', run_in_parallel: true)
end
