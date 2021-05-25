plan background::variables(
  TargetSpec $targets
) {
  $var = 'Before background'
  $future = background() || {
    out::message("Inside background: $var")
    out::message("Targets: ${$targets}")
    out::message("Foo: $foo")
  }
  $foo = 'After background'
  out::message("In main plan: $foo")
}
