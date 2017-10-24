require 'logger'

module Bolt
  class Formatter < Logger::Formatter
    def call(severity, time, progname, msg)
      "#{format_datetime(time)} #{severity} #{progname}: #{msg2str(msg)}\n"
    end
  end
end
