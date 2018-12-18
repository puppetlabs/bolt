plan plans::get_resources(TargetSpec $nodes) {
  $nodes.get_resources('User')
  return $nodes.get_resources(['user', 'File[/tmp]'])
}
