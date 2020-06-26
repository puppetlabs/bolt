plan inventory::transport (
  TargetSpec $targets
) {
  $target = get_target($targets)
  return $target.transport.chomp
}
