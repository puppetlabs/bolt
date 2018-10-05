class basic::strict() {
  $hash = { a => 1, a => 2 }
  notify { 'hello': message => $hash }
}
