plan plans::upload(TargetSpec $nodes) {
  upload_file('plans/dir/prep', '/b', $nodes)
  return upload_file('plans/script', '/d', $nodes)
}
