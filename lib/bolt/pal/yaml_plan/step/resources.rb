# frozen_string_literal: true

module Bolt
  class PAL
    class YamlPlan
      class Step
        class Resources < Step
          def self.required_keys
            Set['resources', 'targets']
          end

          def initialize(body)
            super
            @body['resources'] = normalize_resources(@body['resources'])
          end

          def self.validate(body, step_number)
            super

            body['resources'].each do |resource|
              if resource['type'] || resource['title']
                if !resource['type']
                  err = "Resource declaration must include type key if title key is set"
                  raise StepError.new(err, body['name'], step_number)
                elsif !resource['title']
                  err = "Resource declaration must include title key if type key is set"
                  raise StepError.new(err, body['name'], step_number)
                end
              else
                type_keys = (resource.keys - ['parameters'])
                if type_keys.empty?
                  err = "Resource declaration is missing a type"
                  raise StepError.new(err, body['name'], step_number)
                elsif type_keys.length > 1
                  err = "Resource declaration has ambiguous type: could be #{type_keys.join(' or ')}"
                  raise StepError.new(err, body['name'], step_number)
                end
              end
            end
          end

          # What if this comes from a code block?
          def normalize_resources(resources)
            resources.map do |resource|
              if resource['type'] && resource['title']
                type = resource['type']
                title = resource['title']
              else
                type, = (resource.keys - ['parameters'])
                title = resource[type]
              end

              { 'type' => type, 'title' => title, 'parameters' => resource['parameters'] || {} }
            end
          end

          def transpile
            code = StringIO.new

            code.print "  "
            code << function_call('apply_prep', [@body['targets']])
            code.print "\n"

            code.print "  "
            code.print "$#{@body['name']} = " if @body['name']

            code.puts "apply(#{Bolt::Util.to_code(@body['targets'])}) {"

            declarations = @body['resources'].map do |resource|
              type = resource['type'].is_a?(EvaluableString) ? resource['type'].value : resource['type']
              title = Bolt::Util.to_code(resource['title'])
              parameters = resource['parameters'].transform_values do |val|
                Bolt::Util.to_code(val)
              end

              resource_str = StringIO.new
              if parameters.empty?
                resource_str.puts "    #{type} { #{title}: }"
              else
                resource_str.puts "    #{type} { #{title}:"
                parameters.each do |key, val|
                  resource_str.puts "      #{key} => #{val},"
                end
                resource_str.puts "    }"
              end
              resource_str.string
            end

            code.puts declarations.join("    ->\n")

            code.puts "  }\n"
            code.string
          end
        end
      end
    end
  end
end
