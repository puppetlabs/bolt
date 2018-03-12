step 'Install Bolt package' do
  bolt_sha = ENV['SHA']

  install_puppetlabs_dev_repo(bolt, 'bolt', bolt_sha, 'repo-configs')
  bolt.install_package('bolt')
  add_puppet_paths_on(bolt)
end
