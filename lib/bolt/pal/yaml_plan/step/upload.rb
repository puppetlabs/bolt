# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Upload < Step
          def self.allowed_keys
            super + Set['source', 'destination']
          end

          def self.required_keys
            Set['target', 'source', 'destination']
          end

          def initialize(step_body)
            super
            @source = step_body['source']
            @destination = step_body['destination']
          end

          def transpile
            code = String.new("  ")
            code << "$#{@name} = " if @name

            fn = 'upload_file'
            args = [@source, @destination, @target]
            args << @description if @description

            code << function_call(fn, args)

            code << "\n"
          end
        end
      end
    end
  end
end
