plan exercise7::writeread (
  TargetSpec $nodes,
  String     $filename,
  String     $content = 'Hello',
) {
  run_task(
    'exercise7::write',
    $nodes,
    filename => $filename,
    content  => $content,
  )
  return run_command("cat /tmp/${filename}", $nodes)
}
