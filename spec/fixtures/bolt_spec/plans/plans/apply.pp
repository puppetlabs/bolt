plan plans::apply(TargetSpec $nodes) {
  apply($nodes) {
    file { '/tmp/foo':
      content => 'Hello world!',
    }
  }
  return apply($nodes) {
    notify { 'Hey there!': }
  }
}
