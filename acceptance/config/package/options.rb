# frozen_string_literal: true

{
  pre_suite: [
    'setup/package/pre-suite/015_install_puppet_agent_repo.rb',
    'setup/package/pre-suite/020_install.rb',
    'setup/common/pre-suite/050_build_bolt_inventory.rb'
  ],
  load_path: './lib/acceptance'
}
