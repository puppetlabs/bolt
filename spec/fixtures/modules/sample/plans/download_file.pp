plan sample::download_file(
  TargetSpec $nodes,
) {
  return download_file('/etc/hosts', 'subdir', $nodes)
}
