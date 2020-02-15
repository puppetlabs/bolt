plan write_file(
  TargetSpec $target,
  String $content,
  String $destination
) {
  return write_file($content, $destination, $target)
}
