plan test_project::apply(
  TargetSpec $targets
) {
  return apply($targets) {
    include test_project::notify
  }
}


