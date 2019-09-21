plan catch_errors(
  TargetSpec $nodes,
  Boolean $fail = true
) {
  $errors = catch_errors() || {
    if $fail {
      run_task('error::fail', $nodes)
    } else {
      run_command("echo 'Unepic unfailure'", $nodes)
    }
  }
  notice("Step 1")
  return $errors
}