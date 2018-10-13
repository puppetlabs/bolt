class basic::strict_variables() {
  notify { 'hello': message => "hello ${some_var_name}" }
}
