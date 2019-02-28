plan device_test::set_a_val(
  $key = 'key1',
  $val = 'val1',
  $nodes = 'localhost'
) {
  # rely on the agent already being installed
  apply_prep($nodes)

  $r = apply($nodes) {
    fake_device { $key:
      content => $val
    }
  }
  return $r
}
