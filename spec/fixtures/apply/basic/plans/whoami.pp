plan basic::whoami(TargetSpec $nodes) {
  $result = apply($nodes) {
    exec { "/usr/bin/whoami":
      logoutput => true,
    }
  }
  return $result.first.report['logs']
}
