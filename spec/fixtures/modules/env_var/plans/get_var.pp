plan env_var::get_var (
  TargetSpec $nodes) {
  return( apply($nodes) {
    notify { 'gettingvar':
      message => Deferred('env_var::get_var', ['test_var']),
    }
    })
}
