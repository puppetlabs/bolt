require 'bolt/transports'

class Bolt::CLI
  def initialize(argv)
    @argv = argv
  end

  def execute
    # host user command port password
    Bolt::Transports::SSH.execute(*@argv)
  end
end
