def install_ruby_from_source(host)
  ENV['RUBY_URL'] ||= "https://artifactory.delivery.puppetlabs.net/artifactory/generic__buildsources/buildsources/ruby-2.4.4.tar.gz"
  on(host, "mkdir ruby")
  on(host, "curl -o ruby.tar.gz #{ENV['RUBY_URL']}")
  on(host, "tar -xvf ruby.tar.gz")
  on(host, "cd $(ls | grep 'ruby-') && ./configure && make && make install")
end
