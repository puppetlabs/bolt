plan resource(
  TargetSpec $targets
) {
  $t = get_target($targets)
  $t.set_resources({'type' => 'File',
                    'title' => '/fake/path'})
  return $t.resource('File', '/fake/path')
}
