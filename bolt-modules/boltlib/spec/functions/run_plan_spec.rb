# frozen_string_literal: true

require 'spec_helper'
require 'puppet_pal'
require 'bolt/executor'

describe 'run_plan' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:tasks_enabled) { true }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    executor.stubs(:noop).returns(false)

    Puppet.override(bolt_executor: executor) do
      example.run
    end
  end

  context "when invoked" do
    context 'can be called as' do
      it 'run_plan(name) referencing a plan defined in the manifest' do
        env = Puppet.lookup(:current_environment)
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: env.modulepath) do |pal|
          pal.with_script_compiler do |compiler|
            compiler.evaluate_string(<<-CODE)
            plan run_me() { return "worked1" }
            run_plan('run_me')
            CODE
          end
        end
        expect(result).to eql('worked1')
      end

      it 'run_plan(name) referencing an autoloaded plan in a module' do
        is_expected.to run.with_params('test::run_me').and_return('worked2')
      end

      it 'run_plan(name, hash) where hash is mapping argname to value' do
        is_expected.to run.with_params('test::run_me_int', 'x' => 3).and_return(3)
      end

      it 'run_plan(name, hash) where hash includes _run_as' do
        executor.stubs(:run_as).returns('foo')
        executor.expects(:run_as=).with('bar')
        executor.expects(:run_as=).with('foo')

        is_expected.to run.with_params('test::run_me', '_run_as' => 'bar').and_return('worked2')
      end
    end

    it 'reports the function call to analytics' do
      executor.expects(:report_function_call).with('run_plan')
      executor.expects(:report_bundled_content).with('Plan', 'test::run_me').once
      is_expected.to run.with_params('test::run_me').and_return('worked2')
    end

    it 'skips reporting the function call to analytics if called internally from Bolt' do
      executor.expects(:report_function_call).never
      is_expected.to run.with_params('test::run_me', '_bolt_api_call' => true).and_return('worked2')
    end

    context 'using the name of the module' do
      it 'the plans/init.pp is found and called' do
        is_expected.to run.with_params('test').and_return('worked4')
      end
    end

    context 'handles exceptions by' do
      it 'failing with error for non-existent plan name' do
        is_expected.to run.with_params('not_a_plan_name').and_raise_error(
          /Could not find a plan named "not_a_plan_name"/
        )
      end

      it 'failing with type mismatch error if given args does not match parameters' do
        is_expected.to run.with_params('test::run_me_int', 'x' => 'should not work')
                          .and_raise_error(/expects an Integer value/)
      end
    end

    it 'fails when a plan returns an unexpected result' do
      is_expected.to run.with_params('test::bad_return').and_raise_error(/invalid result/)
    end

    it 'returns undef for plans without explicit return' do
      is_expected.to run.with_params('test::no_return').and_return(nil)
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }
    it 'fails and reports that run_plan is not available' do
      is_expected.to run.with_params('test::run_me')
                        .and_raise_error(/Plan language function 'run_plan' cannot be used/)
    end
  end
end
