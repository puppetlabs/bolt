plan plans::out_message(Array[String] $messages) {
  $messages.each |$message| {
    out::message($message)
  }
}
