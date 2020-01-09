plan basic::node_default(TargetSpec $nodes) {
  return apply($nodes) {
    node default {
      warn { "default node definition": }
    }
  }
}

