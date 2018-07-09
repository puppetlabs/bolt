# frozen_string_literal: true

test_name "Install puppetlabs-facts" do
  on(hosts, puppet('module', 'install', 'puppetlabs-facts', '--target-dir', '$HOME/.puppetlabs/bolt/modules'))
end
