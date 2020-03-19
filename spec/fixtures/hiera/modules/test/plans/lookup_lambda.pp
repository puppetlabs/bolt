plan test::lookup_lambda(
  String $key,
  Hash   $options = {}
) {
  return lookup($key, $options) |$key| {
    "${regsubst($key, '::', ' ', 'G')} lambda"
  }
}
