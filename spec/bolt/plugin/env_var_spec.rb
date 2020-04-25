# frozen_string_literal: true

require 'spec_helper'
require 'bolt/plugin/env_var'
require 'io/console'

describe Bolt::Plugin::EnvVar do
  let(:env_var_data) { { '_plugin' => 'env_var', 'var' => 'BOLT_ENV_VAR' } }

  before(:each) { ENV['BOLT_ENV_VAR'] = 'bolt' }
  after(:each) { ENV.delete('BOLT_ENV_VAR') }

  it 'raises a validation error when no var is provided' do
    env_var_data.delete('var')
    expect { subject.validate_resolve_reference(env_var_data) }
      .to raise_error(Bolt::ValidationError, /env_var plugin requires that the 'var' is specified/)
  end

  it 'raises a validation error when the var is not set' do
    ENV.delete('BOLT_ENV_VAR')
    expect { subject.validate_resolve_reference(env_var_data) }
      .to raise_error(Bolt::ValidationError, /env_var plugin requires that the var 'BOLT_ENV_VAR' be set/)
  end

  it 'returns the value of the environment variable' do
    expect(subject.resolve_reference(env_var_data)).to eq('bolt')
  end

  describe 'when optional is true' do
    let(:env_var_data) { super().merge({ 'optional' => true }) }
    it 'raises a validation error when no var is provided' do
      env_var_data.delete('var')
      expect { subject.validate_resolve_reference(env_var_data) }
        .to raise_error(Bolt::ValidationError, /env_var plugin requires that the 'var' is specified/)
    end

    it 'returns undef when the var is not set' do
      ENV.delete('BOLT_ENV_VAR')
      expect { subject.validate_resolve_reference(env_var_data).to be_nil }
    end
  end

  describe 'when default_value is provided' do
    let(:env_var_data) { super().merge({ 'default_value' => 'DEFAULT_STRING' }) }
    it 'raises a validation error when no var is provided' do
      env_var_data.delete('var')
      expect { subject.validate_resolve_reference(env_var_data) }
        .to raise_error(Bolt::ValidationError, /env_var plugin requires that the 'var' is specified/)
    end

    it 'returns the default value when no var is provided' do
      ENV.delete('BOLT_ENV_VAR')
      expect(subject.resolve_reference(env_var_data)).to eq 'DEFAULT_STRING'
    end
  end
end
