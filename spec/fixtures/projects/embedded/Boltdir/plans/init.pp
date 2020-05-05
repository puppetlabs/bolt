plan embedded(
  TargetSpec $targets
) {
  $target_object = get_target($targets)
  return run_command("echo polo", $target_object)
}

