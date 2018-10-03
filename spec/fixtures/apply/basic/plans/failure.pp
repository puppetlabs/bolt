plan basic::failure (TargetSpec $nodes) {
  return apply($nodes) {
    package {'nonexistentpackagename': }
  }
}
