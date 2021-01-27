# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Upload < Step
          def self.allowed_keys
            super + Set['destination', 'upload']
          end

          def self.required_keys
            Set['upload', 'destination', 'targets']
          end

          def initialize(step_body)
            super
            @source = step_body['upload']
            @destination = step_body['destination']
          end

          def transpile
            code = String.new("  ")
            code << "$#{@name} = " if @name

            fn = 'upload_file'
            args = [@source, @destination, @targets]
            args << @description if @description

            code << function_call(fn, args)

            code << "\n"
          end
        end
      end
    end
  end
end
