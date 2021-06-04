plan background::variables(
  TargetSpec $targets,
  Optional[String] $undef = undef
) {
  $var = 'Before background'
  $future = background() || {
    out::message("Inside background: $var")
    out::message("Undef: $undef")
    out::message("Foo: $foo")
  }
  $foo = 'After background'
  out::message("In main plan: $foo")
}
