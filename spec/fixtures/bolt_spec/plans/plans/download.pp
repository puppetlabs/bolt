plan plans::download(TargetSpec $nodes) {
  download_file('plans/dir/prep', 'foo', $nodes)
  return download_file('plans/script', 'foo', $nodes)
}
