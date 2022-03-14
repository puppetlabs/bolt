plan wait::error(
  TargetSpec $targets,
  Optional[Integer] $timeout = undef,
  Optional[Boolean] $catch_errors = false
) {
  $futures = ["Who's on first", "error", "I don't know's on third"].map |$msg| {
    background() || {
      if $msg == "error" {
        return run_command("exit 1", $targets)
      } else {
        out::message($msg)
      }
    }
  }
  if $timeout == undef {
    out::message(wait($futures, '_catch_errors' => $catch_errors)[1].msg)
  } else {
    out::message(wait($futures, $timeout, '_catch_errors' => $catch_errors)[1].msg)
  }
  out::message("Finished main plan.")
}
