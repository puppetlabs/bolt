plan resources::add_event(
  TargetSpec $targets
) {
  $t = get_target($targets)
  $r = ResourceInstance.new({
    'target' => $t,
    'type' => Package,
    'title' => 'openssl'
  })
  $r.add_event({'update' => { 'time' => 'warp' }})
  return $r
}
