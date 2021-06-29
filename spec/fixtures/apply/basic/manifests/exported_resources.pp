class basic::exported_resources() {
  @@file { 'helloworld.txt':
    content => 'hello world',
  }

  File <<| |>>
}
