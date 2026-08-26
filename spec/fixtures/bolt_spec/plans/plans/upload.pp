plan plans::upload(TargetSpec $nodes, String $source) {
  upload_file($source, '/b', $nodes)
  upload_file('plans/files/../resources/bar', '/o', $nodes)
  return upload_file('plans/script', '/d', $nodes)
}
