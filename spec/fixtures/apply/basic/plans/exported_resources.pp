plan basic::exported_resources (
  TargetSpec $targets
) {
  apply($targets) {
    include 'basic::exported_resources'
  }
}
