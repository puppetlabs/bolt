# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Download < Step
          def self.option_keys
            Set['catch_errors', 'run_as']
          end

          def self.required_keys
            Set['download', 'destination', 'targets']
          end

          # Returns an array of arguments to pass to the step's function call
          #
          def args
            args = [@body['download'], @body['destination'], @body['targets']]
            args << @body['description'] if @body['description']
            args << options if options.any?

            args
          end

          # Transpiles the step into the plan language
          #
          def transpile
            code = String.new("  ")
            code << "$#{@name} = " if @name
            code << function_call('download_file', args)
            code << "\n"
          end
        end
      end
    end
  end
end
