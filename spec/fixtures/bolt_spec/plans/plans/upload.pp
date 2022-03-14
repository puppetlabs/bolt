plan plans::upload(TargetSpec $nodes, String $source) {
  upload_file($source, '/b', $nodes)
  return upload_file('plans/script', '/d', $nodes)
}
