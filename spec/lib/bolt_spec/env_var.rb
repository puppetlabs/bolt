# frozen_string_literal: true

module BoltSpec
  module EnvVar
    def with_env_vars(new_vars)
      new_vars.transform_keys!(&:to_s)

      begin
        old_vars = new_vars.keys.collect { |var| [var, ENV.fetch(var, nil)] }.to_h
        ENV.update(new_vars)
        yield
      ensure
        ENV.update(old_vars) if old_vars
      end
    end
  end
end
