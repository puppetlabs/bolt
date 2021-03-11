plan container::volume(
  String $image = 'ubuntu:14.04',
  String $ls,
  String $src,
  String $dest
) {
  $opts = { 'volumes' => { $src => $dest }, 'cmd' => "${$ls} ${$dest}", 'rm' => true}
  return run_container($image, $opts)
}
