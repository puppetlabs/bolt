# frozen_string_literal: true

Puppet::Functions.create_function(:'env_var::get_var') do
  dispatch :get do
    param 'String', :var
  end

  def get(var)
    ENV[var]
  end
end
