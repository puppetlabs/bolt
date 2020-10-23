# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bolt/version'

Gem::Specification.new do |spec|
  spec.name          = "bolt"
  spec.version       = Bolt::VERSION
  spec.authors       = ["Puppet"]
  spec.email         = ["puppet@puppet.com"]

  spec.summary       = "Execute commands remotely over SSH and WinRM"
  spec.description   = "Execute commands remotely over SSH and WinRM"
  spec.homepage      = "https://github.com/puppetlabs/bolt"
  spec.license       = "Apache-2.0"
  spec.files         = Dir['exe/*'] +
                       Dir['lib/**/*.rb'] +
                       Dir['lib/**/*.json'] +
                       Dir['libexec/*'] +
                       Dir['bolt-modules/*/lib/**/*.rb'] +
                       Dir['bolt-modules/*/types/**/*.pp'] +
                       Dir['modules/*/metadata.json'] +
                       Dir['modules/*/bolt_plugin.json'] +
                       Dir['modules/*/data/**/*'] +
                       Dir['modules/*/facts.d/**/*'] +
                       Dir['modules/*/files/**/*'] +
                       Dir['modules/*/functions/**/*'] +
                       Dir['modules/*/lib/**/*.rb'] +
                       Dir['modules/*/locales/**/*'] +
                       Dir['modules/*/manifests/**/*'] +
                       Dir['modules/*/plans/**/*.pp'] +
                       Dir['modules/*/tasks/**/*'] +
                       Dir['modules/*/templates/**/*'] +
                       Dir['modules/*/types/**/*'] +
                       Dir['Puppetfile'] +
                       Dir['guides/*.txt']
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "~> 2.5"

  spec.add_dependency "addressable", '~> 2.5'
  spec.add_dependency "aws-sdk-ec2", '~> 1'
  spec.add_dependency "bootsnap", "~> 1.5"
  spec.add_dependency "CFPropertyList", "~> 2.2"
  spec.add_dependency "concurrent-ruby", "~> 1.0"
  spec.add_dependency "ffi", "< 1.14.0"
  spec.add_dependency "hiera-eyaml", "~> 3"
  spec.add_dependency "jwt", "~> 2.2"
  spec.add_dependency "logging", "~> 2.2"
  spec.add_dependency "minitar", "~> 0.6"
  spec.add_dependency "net-scp", "~> 1.2"
  spec.add_dependency "net-ssh", ">= 4.0"
  spec.add_dependency "net-ssh-krb", "~> 0.5"
  spec.add_dependency "orchestrator_client", "~> 0.5"
  spec.add_dependency "puppet", ">= 6.18.0"
  spec.add_dependency "puppetfile-resolver", "~> 0.5"
  spec.add_dependency "puppet-resource_api", ">= 1.8.1"
  spec.add_dependency "puppet-strings", "~> 2.3"
  spec.add_dependency "r10k", "~> 3.1"
  spec.add_dependency "ruby_smb", "~> 1.0"
  spec.add_dependency "terminal-table", "~> 1.8"
  spec.add_dependency "winrm", "~> 2.0"
  spec.add_dependency "winrm-fs", "~> 1.3"

  # there is a bug in puppetlabs_spec_helper for modules without fixtures
  spec.add_development_dependency "bundler", ">= 1.14"
  spec.add_development_dependency "octokit", "~> 4.0"
  spec.add_development_dependency "puppetlabs_spec_helper", "<= 2.15.0"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
