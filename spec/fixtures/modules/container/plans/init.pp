plan container(
  String $image = 'ubuntu:18.04'
) {
  return run_container($image, 'rm' => true)
}
