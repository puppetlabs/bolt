plan plans::script(TargetSpec $nodes) {
  run_script('plans/dir/prep', $nodes)
  return run_script('plans/script', $nodes, 'arguments' => ['arg'])
}
