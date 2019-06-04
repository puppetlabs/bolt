class profiles::server(String $site_content) {
  if($facts['os']['family'] == 'redhat') {
    package { 'epel-release':
      ensure => present,
      before => Package['nginx'],
    }
    $html_dir = '/usr/share/nginx/html'
  } else {
    $html_dir = '/var/www/html'
  }

  package { 'nginx':
    ensure => present,
  }

  file { "${html_dir}/index.html":
    content => $site_content,
    ensure  => file,
  }

  service { 'nginx':
    ensure  => 'running',
    enable  => 'true',
    require => Package['nginx'],
  }
}
