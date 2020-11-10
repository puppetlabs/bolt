# frozen_string_literal: true

require 'spec_helper'
require 'puppet_pal'
require 'bolt/executor'
require 'bolt/plugin'
require 'puppet/pops/types/p_sensitive_type'

describe 'run_plan' do
  include PuppetlabsSpec::Fixtures
  let(:executor) { Bolt::Executor.new }
  let(:tasks_enabled) { true }
  let(:inventory) { Bolt::Inventory.empty }

  around(:each) do |example|
    Puppet[:tasks] = tasks_enabled
    executor.stubs(:noop).returns(false)

    Puppet.override(bolt_executor: executor, bolt_inventory: inventory) do
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

      it 'run_plan(name, targets, hash) where targets is the "targets" parameter to the plan' do
        is_expected.to run.with_params('test::run_me_targets', 'target1,target2').and_return('target1,target2')
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
          /Could not find a plan named 'not_a_plan_name'/
        )
      end

      it 'failing with type mismatch error if given args does not match parameters' do
        is_expected.to run.with_params('test::run_me_int', 'x' => 'should not work')
                          .and_raise_error(/expects an Integer value/)
      end

      it 'failing with argument error if given targets positional argument and targets named argument' do
        is_expected.to run.with_params('test::run_me_targets', 'target1', 'targets' => 'target2')
                          .and_raise_error(ArgumentError)
      end

      it 'failing with parse error if given targets positional argument for plan without targets parameter' do
        is_expected.to run.with_params('test::run_me', 'target1')
                          .and_raise_error(Puppet::ParseError)
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

  it 'parameters with type TargetSpec are added to inventory' do
    params = { 'ts' => 'ts',
               'optional_ts' => 'optional_ts',
               'variant_ts' => 'variant_ts',
               'array_ts' => ['array_ts'],
               'nested_ts' => 'nested_ts',
               'string' => 'string',
               'typeless' => 'typeless' }
    expected_targets = %w[ts optional_ts variant_ts array_ts nested_ts]
    is_expected.to run.with_params('test::targetspec_params', params).and_return(expected_targets)
  end

  context 'with a plan with a $targets parameter' do
    it 'fails when given positional argument and targets named argument' do
      is_expected.to run.with_params('test::run_me_targets', 'target1', 'targets' => 'target2')
                        .and_raise_error(ArgumentError)
    end

    it 'specifies the $targets parameter using the second positional argument' do
      is_expected.to run.with_params('test::run_me_targets', 'target1')
                        .and_return('target1')
    end
  end

  context 'with a plan with both a $nodes and $targets parameter' do
    it 'fails when using the second positional argument' do
      is_expected.to run.with_params('test::run_me_nodes_and_targets', 'target1')
                        .and_raise_error(ArgumentError)
    end
  end

  context 'with Sensitive parameters' do
    let(:sensitive) { Puppet::Pops::Types::PSensitiveType::Sensitive }
    let(:string)    { '$up3r$ecr3t!' }
    let(:array)     { [1, 2, 3] }
    let(:hash)      { { 'k' => 'v' } }

    it 'parameters are wrapped as Sensitive' do
      input_params = {
        'array'  => array,
        'hash'   => hash,
        'string' => string
      }

      expected_params = {
        'array'  => sensitive.new(array),
        'hash'   => sensitive.new(hash),
        'string' => sensitive.new(string)
      }

      sensitive.expects(:new).with(input_params['array'])
               .returns(expected_params['array'])
      sensitive.expects(:new).with(input_params['hash'])
               .returns(expected_params['hash'])
      sensitive.expects(:new).with(input_params['string'])
               .returns(expected_params['string'])

      is_expected.to run.with_params('sensitive', input_params.merge('_bolt_api_call' => true))
                        .and_return(input_params)
    end

    it 'parameters are not wrapped from non-API calls' do
      sensitive.expects(:new).never

      is_expected.to run.with_params('sensitive::no_api', 'string' => string)
                        .and_raise_error(
                          Puppet::ParseError,
                          /parameter 'string' expects a Sensitive\[String\]/
                        )
    end

    it 'complex parameters using Sensitive are not wrapped' do
      sensitive.expects(:new).never

      is_expected.to run.with_params('sensitive::complex', 'complex' => string)
                        .and_raise_error(
                          Puppet::ParseError,
                          /parameter 'complex' expects a value of type Sensitive\[String\] or Array/
                        )
    end
  end
end
