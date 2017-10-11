test_name "Install Bolt via git" do
  step "Clone repo" do
    on(bolt, "git clone https://github.com/puppetlabs/bolt.git bolt")
  end
  step "Update submodules" do
    on(bolt, "cd bolt && git submodule update --init --recursive")
  end
  step "Use fake version" do
    create_remote_file(bolt, 'bolt/lib/bolt/version.rb', <<-VERS)
    module Bolt
      VERSION = '9.9.9'.freeze
    end
    VERS
  end
  step "Build gem" do
    on(bolt, "cd bolt && gem build bolt.gemspec")
  end
  step "Install custom gem" do
    on(bolt, "cd bolt && gem install bolt-9.9.9.gem")
  end
  step "Ensure install succeeded" do
    cmd = 'bolt --version'
    case bolt['platform']
    when /windows/
      execute_powershell_script_on(bolt, install_command)
      result = on(bolt, powershell(cmd))
    else
      result = on(bolt, cmd)
    end
    assert_match(/9\.9\.9/, result.stdout)
  end
end
