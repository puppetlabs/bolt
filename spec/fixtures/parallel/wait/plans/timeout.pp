plan wait::timeout(
  TargetSpec $targets,
  Optional[Numeric] $timeout = undef,
  Optional[Numeric] $sleep = 0,
  Optional[Boolean] $catch_errors = false
) {
  $futures = ["Who's on first", "What's on second", "I don't know's on third"].map |$msg| {
    background() || {
      ctrl::sleep($sleep)
      return $msg
    }
  }
  wait($futures, $timeout, '_catch_errors' => $catch_errors)
  return 'Finished the plan'
}
