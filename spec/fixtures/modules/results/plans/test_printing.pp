plan results::test_printing(
  String $host,
  String $user,
  String $password,
  Integer $port
) {
  $target = Target($host, {'user' => $user, 'password' => $password, 'port' => $port})
  notice("Connected to ${target}")
}