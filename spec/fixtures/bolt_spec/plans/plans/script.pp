plan plans::script(TargetSpec $nodes, String $source) {
  run_script($source, $nodes)
  return run_script('plans/script', $nodes, 'arguments' => ['arg'])
}
