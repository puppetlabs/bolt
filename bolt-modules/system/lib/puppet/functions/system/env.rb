# frozen_string_literal: true

# Get an environment variable.
Puppet::Functions.create_function(:'system::env') do
  # @param name Environment variable name.
  # @return The environment variable's value.
  # @example Get the USER environment variable
  #   system::env('USER')
  dispatch :env do
    required_param 'String', :name
    return_type 'Optional[String]'
  end

  def env(name)
    # Send analytics report
    Puppet.lookup(:bolt_executor) {}&.report_function_call(self.class.name)

    ENV[name]
  end
end
