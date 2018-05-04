plan logging::without_default(
  TargetSpec       $nodes,
  Optional[String] $description = undef,
) {
  without_default_logging() || {
    run_task("logging::echo", $nodes, message => "hi there", _catch_errors => true)
  }
}
