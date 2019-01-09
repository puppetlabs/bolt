plan example_apply::puppet_status (TargetSpec $nodes) {
  $targets = get_targets($nodes)
  $targets.each |$target| {
    set_feature($target, 'puppet-agent', true)
  }
  return run_task('service', $targets, 'action' => 'status', 'name' => 'puppet')
}
