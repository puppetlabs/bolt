plan device_test::resources(
  $nodes
) {
  $r = get_resources($nodes, 'Fake_device')
  return $r
}
