require 'bolt/transports'

class Bolt::CLI
  def initialize(argv)
    @argv = argv
  end

  def execute
    if @argv[0] =~ /wsman/
      # endpoint user command password
      Bolt::Transports::WinRM.execute(*@argv)
    else
      # host user command port password
      Bolt::Transports::SSH.execute(*@argv)
    end
  end
end
