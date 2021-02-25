# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Upload < Step
          def self.option_keys
            Set['catch_errors', 'run_as']
          end

          def self.required_keys
            Set['destination', 'targets', 'upload']
          end

          # Returns an array of arguments to pass to the step's function call
          #
          def args
            args = [@body['upload'], @body['destination'], @body['targets']]
            args << @body['description'] if @body['description']
            args << options if options.any?

            args
          end

          # Transpiles the step into the plan language
          #
          def transpile
            code = String.new("  ")
            code << "$#{@body['name']} = " if @body['name']
            code << function_call('upload_file', args)
            code << "\n"
          end
        end
      end
    end
  end
end
