plan example_apply (
  TargetSpec $nodes,
  String $filepath,
  Boolean $noop = false,
) {
  $result = run_plan('facts', nodes => $nodes)
  if !$result.ok {
    return $result
  }

  $targets = get_targets($nodes)
  $targets.each |$t| { $t.set_var('filepath', $filepath) }

  return apply($targets, _noop => $noop) {
    file { $filepath:
      ensure => directory,
    } -> file { "${filepath}/hello.txt":
      ensure  => file,
      content => "hi there I'm ${$facts['os']['family']}\n",
    }
  }
}
