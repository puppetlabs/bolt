lib = File.expand_path('../lib', __FILE__)
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
                       Dir['vendored/*.rb'] +
                       Dir['vendored/*/lib/**/*.rb'] +
                       Dir['bolt-modules/boltlib/lib/**/*.rb'] +
                       Dir['bolt-modules/boltlib/types/**/*.pp'] +
                       Dir['modules/*/lib/**/*.rb'] +
                       Dir['modules/*/plans/**/*.pp']
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "~> 2.1"

  spec.add_dependency "addressable", '< 2.5.0'
  spec.add_dependency "concurrent-ruby", "~> 1.0"
  spec.add_dependency "net-scp", "~> 1.2"
  spec.add_dependency "net-ssh", "~> 4.2"
  spec.add_dependency "orchestrator_client", "~> 0.2.3"
  spec.add_dependency "terminal-table", "~> 1.8.0"
  spec.add_dependency "winrm", "~> 2.0"
  spec.add_dependency "winrm-fs", "~> 1.1.0"
  spec.add_dependency "logging", "~> 2.2"

  # Dependencies of our vendored puppet, etc
  spec.add_dependency "CFPropertyList", "~> 2.2"
  spec.add_dependency "gettext-setup", "< 1", ">= 0.10"
  spec.add_dependency "locale", "~> 2.1"
  spec.add_dependency "minitar", "~> 0.6.1"
  spec.add_dependency "win32-dir", "= 0.4.9"
  spec.add_dependency "win32-process", "= 0.7.5"
  spec.add_dependency "win32-security", "= 0.2.5"
  spec.add_dependency "win32-service", "= 0.8.8"

  # there is a bug in puppetlabs_spec_helper for modules without fixtures
  spec.add_development_dependency "puppetlabs_spec_helper", "~> 2.6"
  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
