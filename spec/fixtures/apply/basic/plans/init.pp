plan basic(TargetSpec $targets) {
  $result = run_plan('facts', targets => $targets)
  if !$result.ok {
    return $result
  }

  return apply($targets) {
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
