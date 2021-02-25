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

          def evaluate(scope, evaluator)
            evaluated = evaluator.evaluate_code_blocks(scope, body)

            scope.call_function('apply_prep', evaluated['targets'])

            manifest = generate_manifest(evaluated['resources'])
            apply_manifest(scope, evaluated['targets'], manifest)
          end

          # Generates a manifest from the resources
          #
          private def generate_manifest(resources)
            # inspect returns the Ruby representation of the resource hashes,
            # which happens to be the same as the Puppet representation
            puppet_resources = resources.inspect

            # Because the :tasks setting globally controls which mode the parser
            # is in, we need to make this snippet of non-tasks manifest code
            # parseable in tasks mode. The way to do that is by putting it in an
            # apply statement and taking the body.
            <<~MANIFEST
            apply('placeholder') {
              $resources = #{puppet_resources}
              $resources.each |$res| {
                Resource[$res['type']] { $res['title']:
                  * => $res['parameters'],
                }
              }
  
              # Add relationships if there is more than one resource
              if $resources.length > 1 {
                ($resources.length - 1).each |$index| {
                  $lhs = $resources[$index]
                  $rhs = $resources[$index+1]
                  $lhs_resource = Resource[$lhs['type'] , $lhs['title']]
                  $rhs_resource = Resource[$rhs['type'] , $rhs['title']]
                  $lhs_resource -> $rhs_resource
                }
              }
            }
            MANIFEST
          end

          # Applies the manifest block on the targets
          #
          private def apply_manifest(scope, targets, manifest)
            ast = self.class.parse_code_string(manifest)
            apply_block = ast.body.body
            applicator = Puppet.lookup(:apply_executor)
            applicator.apply([targets], apply_block, scope)
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

          # Normalizes the resources so they are in a format compatible with apply blocks
          # What if this comes from a code block?
          #
          private def normalize_resources(resources)
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
