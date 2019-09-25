plan basic(TargetSpec $nodes) {
  $result = run_plan('facts', nodes => $nodes)
  if !$result.ok {
    return $result
  }

  return apply($nodes) {
    file { '/root/test/':
      ensure => directory,
    } -> file { '/root/test/hello.txt':
      ensure  => file,
      content => "hi there I'm ${$facts['os']['family']}\n",
    }
  }.map |$r| {
    $r.report['catalog']['resources']
  }
}
