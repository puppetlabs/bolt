# frozen_string_literal: true

require 'spec_helper'
require 'bolt/transport/base'
require 'bolt_spec/sensitive'

describe Bolt::Transport::Base do
  include BoltSpec::Sensitive

  let(:base) { Bolt::Transport::Base.new }

  context "when executing" do
    it "Sensitive String arguments are unwrapped" do
      args = { 'str' => make_sensitive('$ecret!') }
      expected = { 'str' => '$ecret!' }
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end

    it "Sensitive deeply wrapped String arguments are unwrapped" do
      args = { 'str' => make_sensitive(make_sensitive(make_sensitive('$ecret!'))) }
      expected = { 'str' => '$ecret!' }
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end

    it "Sensitive Array arguments are unwrapped" do
      args = { 'arr' => make_sensitive([1, 2, 3]) }
      expected = { 'arr' => [1, 2, 3] }
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end

    it "Sensitive Array elements are unwrapped" do
      args = { 'arr' => [make_sensitive('a'),
                         make_sensitive(1),
                         make_sensitive(true)] }
      expected = { 'arr' => ['a', 1, true] }
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end

    it "Sensitive Hash arguments are unwrapped" do
      nested_hash = { 'k' => 'v' }
      args = { 'hash' => make_sensitive(nested_hash) }
      expected = { 'hash' => { 'k' => 'v' } }
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end

    it "Sensitive Hash keys and values are unwrapped" do
      args = { 'hash' => { make_sensitive('k') => make_sensitive('v') } }
      expected = { 'hash' => { 'k' => 'v' } }
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end

    it "Sensitive deeply nested Hash is unwrapped" do
      arr = [make_sensitive(1),
             make_sensitive(true),
             make_sensitive([make_sensitive('c')])]
      very_deep_hash = { make_sensitive('dk') => make_sensitive('dv') }
      deep_hash = { make_sensitive('k') => make_sensitive(very_deep_hash) }
      args = { 'hash' => { make_sensitive(make_sensitive('arr')) => arr,
                           make_sensitive('deep_hash') => deep_hash } }
      expected = { 'hash' => { 'arr' => [1, true, ['c']],
                               'deep_hash' => { 'k' => { 'dk' => 'dv' } } } }
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end

    it "Sensitive deeply nested Array is unwrapped" do
      deep_hash = { make_sensitive('k') => make_sensitive(['x', false]) }
      args = [make_sensitive('a'),
              deep_hash,
              make_sensitive([make_sensitive('c')])]
      expected = ['a',
                  { 'k' => ['x', false] },
                  ['c']]
      expect(base.unwrap_sensitive_args(args)).to eq(expected)
    end
  end
end
