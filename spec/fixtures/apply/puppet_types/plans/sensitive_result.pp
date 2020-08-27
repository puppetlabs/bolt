plan puppet_types::sensitive_result (
  TargetSpec $targets
) {
  $target = get_target($targets)
  $target.apply_prep

  $result = run_task('sensitive', $target).first

  return apply($target) {
    notify { "Result sensitive value: ${$result.sensitive.unwrap['password']}": }
  }
}

