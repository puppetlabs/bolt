# frozen_string_literal: true

require 'bolt/config/validator'

describe Bolt::Config::Validator do
  def validate
    described_class.new.validate(data, schema, location)
  end

  let(:location) { 'config' }
  let(:data)     { {} }

  context 'validating types' do
    context 'single type' do
      let(:schema) do
        {
          'option' => {
            type: String
          }
        }
      end

      it 'does not error with valid type' do
        data['option'] = 'foo'

        expect { validate }.not_to raise_error
      end

      it 'errors with invalid type' do
        data['option'] = nil

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option' must be of type String/
        )
      end
    end

    context 'multiple types' do
      let(:schema) do
        {
          'option' => {
            type: [String, Integer]
          }
        }
      end

      it 'does not error with valid type' do
        data['option'] = 'foo'

        expect { validate }.not_to raise_error
      end

      it 'errors with no valid type' do
        data['option'] = nil

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option' must be of type String, Integer/
        )
      end
    end

    context 'booleans' do
      let(:schema) do
        {
          'option' => {
            type: [TrueClass, FalseClass]
          }
        }
      end

      it 'includes Boolean in error message' do
        data['option'] = nil

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option' must be of type Boolean/
        )
      end
    end

    context 'without a type definition' do
      let(:schema) do
        {
          'option' => {}
        }
      end

      it 'does not error' do
        data['option'] = 'foo'

        expect { validate }.not_to raise_error
      end
    end
  end

  context 'validating plugins' do
    let(:schema) do
      {
        'option' => {
          type:    String,
          _plugin: true
        }
      }
    end

    let(:data) do
      {
        'option' => {
          '_plugin' => 'myplugin'
        }
      }
    end

    it 'does not error when option accepts plugin references' do
      expect { validate }.not_to raise_error
    end

    it 'errors when option does not accept plugin references' do
      schema['option'][:_plugin] = false

      expect { validate }.to raise_error(
        Bolt::ValidationError,
        /Value at 'option' is a plugin reference, which is unsupported at this location/
      )
    end
  end

  context 'validating hashes' do
    context ':required' do
      let(:schema) do
        {
          'option' => {
            type:     Hash,
            required: ['foo']
          }
        }
      end

      it 'does not error if required key is present' do
        data['option'] = { 'foo' => 'bar' }

        expect { validate }.not_to raise_error
      end

      it 'errors if required key is missing' do
        data['option'] = { 'bar' => 'foo' }

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option' is missing required keys foo/
        )
      end
    end

    context ':properties' do
      let(:schema) do
        {
          'option' => {
            type: Hash,
            properties: {
              'foo' => {
                type: String
              }
            }
          }
        }
      end

      it 'does not error if value for property is valid' do
        data['option'] = { 'foo' => 'bar' }

        expect { validate }.not_to raise_error
      end

      it 'errors if value for property is invalid' do
        data['option'] = { 'foo' => nil }

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option.foo' must be of type String/
        )
      end
    end

    context ':additionalProperties' do
      let(:schema) do
        {
          'option' => {
            type: Hash,
            additionalProperties: {
              type: String
            }
          }
        }
      end

      it 'does not error if additional property is valid' do
        data['option'] = { 'foo' => 'bar' }

        expect { validate }.not_to raise_error
      end

      it 'errors if additional property is invalid' do
        data['option'] = { 'foo' => nil }

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option.foo' must be of type String/
        )
      end
    end
  end

  context 'validating arrays' do
    context ':uniqueItems' do
      let(:schema) do
        {
          'option' => {
            type:        Array,
            uniqueItems: true
          }
        }
      end

      it 'does not error with unique items' do
        data['option'] = [1, 2, 3]

        expect { validate }.not_to raise_error
      end

      it 'errors with duplicate items' do
        data['option'] = [1, 1, 2, 3]

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option' must not include duplicate elements/
        )
      end
    end

    context ':items' do
      let(:schema) do
        {
          'option' => {
            type:  Array,
            items: {
              type: Integer
            }
          }
        }
      end

      it 'does not error with valid items' do
        data['option'] = [1, 2, 3]

        expect { validate }.not_to raise_error
      end

      it 'errors with invalid items' do
        data['option'] = [1, 2, '3']

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option.2' must be of type Integer/
        )
      end
    end
  end

  context 'validating strings' do
    context ':enum' do
      let(:schema) do
        {
          'option' => {
            type: String,
            enum: ['foo']
          }
        }
      end

      it 'does not error with valid value' do
        data['option'] = 'foo'

        expect { validate }.not_to raise_error
      end

      it 'errors with invalid value' do
        data['option'] = 'bar'

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option' must be one of foo/
        )
      end
    end
  end

  context 'validating integers' do
    context ':minimum' do
      let(:schema) do
        {
          'option' => {
            type:    Integer,
            minimum: 1
          }
        }
      end

      it 'does not error with valid value' do
        data['option'] = 10

        expect { validate }.not_to raise_error
      end

      it 'errors with invalid value' do
        data['option'] = 0

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option' must be a minimum of 1/
        )
      end
    end
  end
end
