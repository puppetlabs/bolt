# frozen_string_literal: true

require 'bolt/validator'

describe Bolt::Validator do
  def validate
    described_class.new.tap do |validator|
      validator.validate(data, schema, location)
    end
  end

  let(:location) { 'config' }
  let(:data)     { {} }

  let(:schema) do
    {
      type:       Hash,
      properties: properties
    }
  end

  context 'validating types' do
    context 'single type' do
      let(:properties) do
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
      let(:properties) do
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
          /Value at 'option' must be of type String or Integer/
        )
      end
    end

    context 'booleans' do
      let(:properties) do
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
      let(:properties) do
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
    let(:properties) do
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
      properties['option'][:_plugin] = false

      expect { validate }.to raise_error(
        Bolt::ValidationError,
        /Value at 'option' is a plugin reference, which is unsupported at this location/
      )
    end

    context 'with suboptions' do
      let(:properties) do
        {
          'hash' => {
            type:       Hash,
            _plugin:    true,
            properties: {
              'suboption' => {
                type: String
              }
            }
          },
          'array' => {
            type: Array,
            _plugin: true,
            items: {
              type: String
            }
          },
          'nested' => {
            type: Hash,
            _plugin: true,
            properties: {
              'suboption' => {
                type: Hash,
                properties: {
                  'subsuboption' => {
                    type: String
                  }
                }
              }
            }
          }
        }
      end

      let(:data) do
        {
          'hash' => {
            'suboption' => {
              '_plugin' => 'myplugin'
            }
          },
          'array' => [
            { '_plugin' => 'myplugin' }
          ],
          'nested' => {
            'suboption' => {
              'subsuboption' => {
                '_plugin' => 'myplugin'
              }
            }
          }
        }
      end

      it 'does not error when superoption sets :_plugin' do
        expect { validate }.not_to raise_error
      end

      it 'errors when superoption does not set :_plugin' do
        properties['hash'].delete(:_plugin)
        properties['array'].delete(:_plugin)
        properties['nested'].delete(:_plugin)

        expect { validate }.to raise_error do |error|
          expect(error).to be_a(Bolt::ValidationError)

          expect(error.message.lines).to include(
            /Value at 'hash.suboption' is a plugin reference, which is unsupported at this location/,
            /Value at 'array.0' is a plugin reference, which is unsupported at this location/,
            /Value at 'nested.suboption.subsuboption' is a plugin reference, which is unsupported at this location/
          )
        end
      end
    end
  end

  context 'validating hashes' do
    context ':required' do
      let(:properties) do
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
      let(:properties) do
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
      let(:properties) do
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
      let(:properties) do
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
      let(:properties) do
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
      let(:properties) do
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
          /Value at 'option' must be foo/
        )
      end

      it 'errors with invalid value and suggest alternate type' do
        properties['option'][:type] = [String, Hash]
        data['option']              = 'bar'

        expect { validate }.to raise_error(
          Bolt::ValidationError,
          /Value at 'option' must be foo or must be of type Hash/
        )
      end
    end
  end

  context 'validating integers' do
    context ':minimum' do
      let(:properties) do
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

  context 'validating keys' do
    let(:properties) do
      {
        'nested' => {
          type: Hash,
          properties: {
            'known' => { type: String }
          }
        },
        'no_properties' => {
          type: Hash
        },
        'additional_properties' => {
          type: Hash,
          properties: {
            'known' => { type: String }
          },
          additionalProperties: {
            type: String
          }
        }
      }
    end

    it 'warns with unknown key' do
      data['unknown'] = 'unknown key'
      validator       = validate

      expect(validator.warnings).to include(/Unknown option 'unknown' at config./)
    end

    it 'warns with nested uknown key' do
      data['nested'] = { 'unknown' => 'unknown key' }
      validator      = validate

      expect(validator.warnings).to include(/Unknown option 'unknown' at 'nested' at config./)
    end

    it 'does not warn when :properties is not defined' do
      data['no_properties'] = { 'unknown' => 'unknown key' }
      validator             = validate

      expect(validator.warnings.empty?).to be
    end

    it 'does not warn when :additionalProperties is defined' do
      data['additional_properties'] = { 'unknown' => 'unknown key' }
      validator                     = validate

      expect(validator.warnings.empty?).to be
    end
  end

  context 'adding deprecations' do
    context ':_deprecation' do
      let(:properties) do
        {
          'option' => {
            type:         Integer,
            _deprecation: "Donut use."
          }
        }
      end

      it 'adds a deprecation warning' do
        data['option'] = 100

        described_class.new.tap do |validator|
          validator.validate(data, schema, location)
          expect(validator.deprecations).to include(
            option:  'option',
            message: /Option 'option' at config is deprecated. Donut use./
          )
        end
      end
    end
  end

  context 'with references' do
    let(:schema) do
      {
        type: Hash,
        properties: {
          "option" => { _ref: "option" }
        },
        definitions: {
          "option" => {
            type: Integer
          }
        }
      }
    end

    it 'uses the referenced definition' do
      data['option'] = 'foo'

      described_class.new.tap do |validator|
        expect { validator.validate(data, schema, location) }.to raise_error do |error|
          expect(error.message.lines).to include(/Value at 'option' must be of type Integer/)
        end
      end
    end
  end
end
