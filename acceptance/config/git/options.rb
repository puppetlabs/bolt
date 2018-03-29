# frozen_string_literal: true

{
  pre_suite: [
    'setup/common/pre-suite/010_install_ruby.rb',
    'setup/git/pre-suite/010_install_git.rb',
    'setup/git/pre-suite/020_install.rb',
    'setup/common/pre-suite/050_build_bolt_inventory.rb'
  ],
  load_path: './lib/acceptance',
  ssh: { forward_agent: false }
}
