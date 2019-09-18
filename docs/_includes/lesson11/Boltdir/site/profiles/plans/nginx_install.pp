plan profiles::nginx_install(
  TargetSpec $servers,
  TargetSpec $lb,
  String $site_content = 'hello!',
) {
  if get_targets($lb).size != 1 {
    fail("Must specify a single load balancer, not ${lb}")
  }
  # Ensure puppet tools are installed and gather facts for the apply
  apply_prep([$servers, $lb])

  apply($servers) {
    class { 'profiles::server':
      site_content => "${site_content} from ${$trusted['certname']}\n",
    }
  }

  apply($lb) {
    include haproxy
    haproxy::listen { 'nginx':
      collect_exported => false,
      ipaddress        => $facts['ipaddress'],
      ports            => '80',
    }

    $targets = get_targets($servers)
    $targets.each |Integer $index, Target $target| {
      haproxy::balancermember { "lb_${$index}":
        listening_service => 'nginx',
        server_names      => $target.host,
        ipaddresses       => $target.facts['ipaddress'],
        ports             => '80',
        options           => 'check',
      }
    }
  }
}
