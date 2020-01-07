plan basic::node_definition(TargetSpec $nodes) {
  return apply($nodes) {
    # We don't know the node name that will be used in the test, so we have to
    # just match everything
    node /.+/ {
      warn { "named node definition": }
    }
  }
}
