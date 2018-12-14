plan basic::resources(TargetSpec $nodes) {
  return $nodes.get_resources(['user', 'File[/tmp]'])
}
