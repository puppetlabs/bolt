require 'logger'

module Bolt
  class Node
    class Formatter < Logger::Formatter
      def initialize(host)
        @host = host
      end

      def call(severity, time, _progname, msg)
        "#{format_datetime(time)} #{severity} #{@host}: #{msg2str(msg)}\n"
      end
    end
  end
end
