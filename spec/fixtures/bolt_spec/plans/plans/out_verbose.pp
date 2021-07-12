plan plans::out_verbose(Array[String] $messages) {
  $messages.each |$message| {
    out::verbose($message)
  }
}
