plan container::apply(
  TargetSpec $targets
) {
  apply_prep($targets)
  $r = run_container('ubuntu:14.04', 'rm' => true, 'cmd' => 'whoami')
  return apply($targets) {
    notify { $r.stdout: }
  }
}
