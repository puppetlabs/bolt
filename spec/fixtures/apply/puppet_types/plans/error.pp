plan puppet_types::error(
  TargetSpec $targets
) {
  $first = get_target($targets)
  $first.apply_prep

  $error = run_command("not real", $targets, _catch_errors => true)
  return apply($first) {
    notify { "ApplyResult resource: ${$error[0].error.message}": }
  }
}
