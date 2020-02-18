plan results::test_printing(
  String $host,
  String $user,
  String $password,
  Integer $port
) {
  $config = {
    'local' => {
      'user' => $user,
      'password' => $password,
      'port' => $port
    }
  }
  $target = Target.new({'name' => $host, 'config' => $config})
  notice("Connected to ${target.name}")
}
