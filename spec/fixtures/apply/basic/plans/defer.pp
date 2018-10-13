plan basic::defer(TargetSpec $nodes) {
  return apply($nodes) {
    notify { 'local pid':
      message => pid(),
    }
    notify { 'remote pid':
      message => Deferred('pid', []),
    }
  }
}
