plan test::id(
  String $target
) {
  [
    run_task(test::id, [$target]),
    run_task(test::id, [$target], '_run_as' => 'root'),

    run_command('id -un', [$target]),
    run_command('id -un', [$target], '_run_as' => 'root'),

    run_script('test/id.sh', [$target]),
    run_script('test/id.sh', [$target], '_run_as' => 'root'),
  ].map |$rset| {
    $rset.map |$r| {
      if $r["stdout"] {
        $r["stdout"]
      } else {
        $r["_output"]
      }
    }
  }.reduce |$arr, $output| {
    $arr + $output
  }
}
