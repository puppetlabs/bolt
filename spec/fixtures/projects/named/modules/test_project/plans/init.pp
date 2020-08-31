plan test_project(
  TargetSpec $targets
) {
  fail_plan("This plan should be shadowed by the project")
}
