# frozen_string_literal: true

{
  pre_suite: [
    'setup/package/pre-suite/020_install.rb',
    'setup/common/pre-suite/030_set_password.rb',
    'setup/common/pre-suite/050_build_bolt_inventory.rb',
    'setup/common/pre-suite/070_install_puppet.rb'
  ],
  load_path: './lib/acceptance'
}
