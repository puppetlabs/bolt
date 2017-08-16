# coding: utf-8

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
  spec.license       = "Apache2"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "net-ssh", "~> 4.0"
  spec.add_dependency "winrm", "~> 2.0"
  spec.add_dependency "trollop", "~> 2.0"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
