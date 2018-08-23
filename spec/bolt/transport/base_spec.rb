# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/base'
require 'puppet/pops/types/p_sensitive_type'

Sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive

describe Bolt::Transport::Base do

  let(:base) { Bolt::Transport::Base.new }

  context "when executing" do
    it "Sensitive String arguments are unwrapped" do
      args = {'str' => Sensitive.new('$ecret!')}
      expect(base.unwrap_sensitive_args(args)).to eq({'str' => '$ecret!'})
    end
    
    it "Sensitive deeply wrapped String arguments are unwrapped" do
      args = {'str' => Sensitive.new(Sensitive.new(Sensitive.new('$ecret!')))}
      expect(base.unwrap_sensitive_args(args)).to eq({'str' => '$ecret!'})
    end
    
    it "Sensitive Array arguments are unwrapped" do
      args = {'arr' => Sensitive.new([1, 2, 3])}
      expect(base.unwrap_sensitive_args(args)).to eq({'arr' => [1, 2, 3]})
    end

    it "Sensitive Array elements are unwrapped" do
      args = {'arr' => [Sensitive.new('a'),
                        Sensitive.new('b'),
                        Sensitive.new('c')]}
      expect(base.unwrap_sensitive_args(args)).to eq({'arr' => ['a', 'b', 'c']})
    end
    
    it "Sensitive Hash arguments are unwrapped" do
      args = {'hash' => Sensitive.new({'k' => 'v'})}
      expect(base.unwrap_sensitive_args(args)).to eq({'hash' => {'k' => 'v'}})
    end

    it "Sensitive Hash keys and values are unwrapped" do
      args = {'hash' => {Sensitive.new('k') => Sensitive.new('v')}}
      expect(base.unwrap_sensitive_args(args)).to eq({'hash' => {'k' => 'v'}})
    end

    it "Sensitive deeply nested Hash is unwrapped" do
      arr = [Sensitive.new(1),
             Sensitive.new(true),
             Sensitive.new([Sensitive.new('c')])]
      deep_hash = {Sensitive.new('k') => Sensitive.new({Sensitive.new('dk') =>
                                                        Sensitive.new('dv')})}
      args = {'hash' => {Sensitive.new(Sensitive.new('arr')) => arr,
                         Sensitive.new('deep_hash') => deep_hash}}
      expected = {'hash' => {'arr' => [1, true, ['c']],
                             'deep_hash' => {'k' => {'dk' => 'dv'}}}}
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end
    
    it "Sensitive deeply nested Array is unwrapped" do
      
      deep_hash = {Sensitive.new('k') => Sensitive.new(['x', false])}
      args = [Sensitive.new('a'),
             deep_hash,
             Sensitive.new([Sensitive.new('c')])]
      expected = ['a',
                  {'k' => ['x', false]},
                  ['c']]
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end
  end
end
