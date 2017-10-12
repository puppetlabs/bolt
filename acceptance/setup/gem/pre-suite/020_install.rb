gem_source = ENV['GEM_SOURCE'] || "https://rubygems.org"
gem_version = ENV['BOLT_GEM'] || ""

test_name "Install Bolt gem" do
  step "Install Bolt gem" do
    install_command = "gem install bolt --source #{gem_source}"
    install_command += " -v '#{gem_version}'" unless gem_version.empty?
    result = nil
    case bolt['platform']
    when /windows/
      execute_powershell_script_on(bolt, install_command)
      result = on(bolt, powershell('bolt --help'))
    else
      on(bolt, install_command)
      result = on(bolt, 'bolt --help')
    end
    assert_match(/Usage: bolt <subcommand>/, result.stdout)
  end
end
