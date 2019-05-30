# frozen_string_literal: true

{
  pre_suite: [
    'setup/common/pre-suite/010_install_ruby.rb',
    'setup/git/pre-suite/010_install_git.rb',
    'setup/git/pre-suite/020_install.rb',
    'setup/common/pre-suite/030_set_password.rb',
    'setup/common/pre-suite/031_add_local_nix_user.rb',
    'setup/common/pre-suite/032_configure_windows_profile.rb',
    'setup/common/pre-suite/050_build_bolt_inventory.rb',
    'setup/common/pre-suite/071_install_modules.rb'
  ],
  load_path: './lib/acceptance',
  ssh: { forward_agent: false }
}
