plan basic::catch_error(TargetSpec $nodes, Boolean $catch) {
  $result = apply($nodes, _catch_errors => $catch) {
    fail('stop the insanity')
  }

  return $result.first.error
}
