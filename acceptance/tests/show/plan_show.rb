require 'bolt_command_helper'
extend Acceptance::BoltCommandHelper

test_name "A user can use 'plan show'" do
  dir = bolt.tmpdir('plan_show')

  flags = {
    '--modulepath' => "#{dir}/modules"
  }

  step "create three plans on bolt controller" do
    on(bolt, "mkdir -p #{dir}/modules/test/{tasks,plans}")
    on(bolt, "mkdir -p #{dir}/modules/test2/{tasks,plans}")
    create_remote_file(bolt, "#{dir}/modules/test/plans/one.pp", <<-ONE)
    plan test::one($nodes, $foo, $bar) {
    }
    ONE
    create_remote_file(bolt, "#{dir}/modules/test/plans/two.pp", <<-TWO)
    plan test::two($nodes, $foo, $bar) {
    }
    TWO
    create_remote_file(bolt, "#{dir}/modules/test2/plans/init.pp", <<-INIT)
    plan test2(
      String $nodes, Optional[String] $rubber, Array $baby, Enum['off'] $buggy, String $bumpers = 'bar') {
    }
    INIT
  end

  step "show available plans" do
    bolt_command = "bolt plan show"
    result = bolt_command_on(bolt, bolt_command, flags)
    all_tasks_match = [
      /test2/,
      /test::one/,
      /test::two/
    ].all? do |plan_name|
      result.output =~ plan_name
    end
    assert(all_tasks_match, "'#{bolt_command}' did not list the expected tasks observed: #{result.output}")
  end

  step "show a specific plan" do
    bolt_command = "bolt plan show test2"
    result = bolt_command_on(bolt, bolt_command, flags)
    all_parameters_match = [
      /- nodes: String/,
      /- rubber: Optional\[String\]/,
      /- baby: Array/,
      /- buggy: Enum\['off'\]/,
      /- bumpers: String/
    ].all? do |regex|
      result.output =~ regex
    end
    assert(all_parameters_match, "#{bolt_command} did not list the expected parameters #{result.output}")
  end
end
