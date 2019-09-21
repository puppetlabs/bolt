plan catch_errors::typed(
  TargetSpec $nodes,
  Boolean $fail_task = false,
  Boolean $fail_plan = false,
  Array $errors = ['puppetlabs.tasks/task-error']
) {
  $typed = catch_errors($errors) || {
    run_task('error::typed', $nodes, 'fail' => $fail_task)
    if $fail_plan {
      run_plan('basic::failure', nodes => $nodes)
    }
    return "Ran with out error"
  }
  notice("Step 2")
  $hash = { 'error' => $typed, 'msg' => 'Success' }
  return $hash
}