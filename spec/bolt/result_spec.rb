# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'bolt'
require 'bolt/result'

describe Bolt::Result do
  let(:target) { "foo" }

  describe :initialize do
    it 'sets default values' do
      result = Bolt::Result.new(target)
      expect(result.target).to eq('foo')
      expect(result.value).to eq({})
      expect(result.action).to eq('action')
      expect(result.object).to eq(nil)
    end

    it 'sets error' do
      result = Bolt::Result.new(target, error: { 'This' => 'is an error' })
      expect(result.error_hash).to eq('This' => 'is an error')
      expect(result.value['_error']).to eq('This' => 'is an error')
    end

    it 'errors if error is not a hash' do
      expect { Bolt::Result.new(target, error: 'This is an error') }
        .to raise_error(RuntimeError, 'TODO: how did we get a string error')
    end

    it 'sets message' do
      result = Bolt::Result.new(target, message: 'This is a message')
      expect(result.message).to eq('This is a message')
      expect(result.value['_output']).to eq('This is a message')
    end
  end

  describe :from_exception do
    let(:result) do
      ex = RuntimeError.new("oops")
      ex.set_backtrace('/path/to/bolt/node.rb:42')
      Bolt::Result.from_exception(target, ex)
    end

    it 'has an error' do
      expect(result.error_hash['msg']).to eq("oops")
    end

    it 'has a target' do
      expect(result.target).to eq(target)
    end

    it 'does not have a message' do
      expect(result.message).to be_nil
    end

    it 'has an _error in value' do
      expect(result.value['_error']['msg']).to eq("oops")
    end

    it 'sets default action' do
      expect(result.action).to eq('action')
    end

    it 'sets action when specified as an argument' do
      ex = RuntimeError.new("oops")
      ex.set_backtrace('/path/to/bolt/node.rb:42')
      result = Bolt::Result.from_exception(target, ex, action: 'custom_action')
      expect(result.action).to eq('custom_action')
    end
  end

  describe :for_command do
    it 'exposes value' do
      result = Bolt::Result.for_command(target, "stout", "sterr", 0, 'command', 'command')
      expect(result.value).to eq('stdout' => 'stout', 'stderr' => 'sterr', 'exit_code' => 0)
    end

    it 'creates errors' do
      result = Bolt::Result.for_command(target, "stout", "sterr", 1, 'command', 'command')
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/command-error')
    end
  end

  describe :for_task do
    it 'parses json objects' do
      obj = { "key" => "val" }
      result = Bolt::Result.for_task(target, obj.to_json, '', 0, 'atask')
      expect(result.value).to eq(obj)
    end

    it 'marks _sensitive values as sensitive' do
      obj = { "user" => "someone", "_sensitive" => { "password" => "sosecretive" } }
      result = Bolt::Result.for_task(target, obj.to_json, '', 0, 'atask')
      expect(result.sensitive).to be_a(Puppet::Pops::Types::PSensitiveType::Sensitive)
      expect(result.sensitive.unwrap).to eq('password' => 'sosecretive')
    end

    it 'excludes _output and _error from generic_value' do
      obj = { "key" => "val" }
      special = { "_error" => {}, "_output" => "output" }
      result = Bolt::Result.for_task(target, obj.merge(special).to_json, '', 0, 'atask')
      expect(result.generic_value).to eq(obj)
    end

    it 'includes _sensitive in generic_value' do
      obj = { "user" => "someone", "_sensitive" => { "password" => "sosecretive" } }
      result = Bolt::Result.for_task(target, obj.to_json, '', 0, 'atask')
      expect(result.generic_value.keys).to include('user', '_sensitive')
    end

    it "doesn't parse arrays" do
      stdout = '[1, 2, 3]'
      result = Bolt::Result.for_task(target, stdout, '', 0, 'atask')
      expect(result.value).to eq('_output' => stdout)
    end

    it 'handles errors' do
      obj = { "key" => "val",
              "_error" => { "kind" => "error" } }
      result = Bolt::Result.for_task(target, obj.to_json, '', 1, 'atask')
      expect(result.value).to eq(obj)
      expect(result.error_hash).to eq(obj['_error'])
    end

    it 'uses the unparsed value of stdout if it is not valid JSON' do
      stdout = 'just some string'
      result = Bolt::Result.for_task(target, stdout, '', 0, 'atask')
      expect(result.value).to eq('_output' => 'just some string')
    end

    it 'generates an error for binary data' do
      stdout = "\xFC].\xF9\xA8\x85f\xDF{\x11d\xD5\x8E\xC6\xA6"
      result = Bolt::Result.for_task(target, stdout, '', 0, 'atask')
      expect(result.value.keys).to eq(['_error'])
      expect(result.error_hash['msg']).to match(/The task result contained invalid UTF-8/)
    end

    it 'generates an error for non-UTF-8 output' do
      stdout = "☃".encode('utf-32')
      result = Bolt::Result.for_task(target, stdout, '', 0, 'atask')
      expect(result.value.keys).to eq(['_error'])
      expect(result.error_hash['msg']).to match(/The task result contained invalid UTF-8/)
    end
  end
end
