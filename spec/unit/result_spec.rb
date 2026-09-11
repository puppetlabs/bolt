# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'bolt'
require 'bolt/target'
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
      value = {
        'stdout'        => 'stdout',
        'stderr'        => 'stderr',
        'merged_output' => "stdout\nstderr",
        'exit_code'     => 0
      }

      result = Bolt::Result.for_command(target, value, 'command', 'command', [])
      expect(result.value).to eq(value)
    end

    it 'creates errors' do
      value = {
        'stdout'        => 'stdout',
        'stderr'        => 'stderr',
        'merged_output' => "stdout\nstderr",
        'exit_code'     => 1
      }

      result = Bolt::Result.for_command(target, value, 'command', 'command', ['/jacko/lantern', 6])
      expect(result.error_hash['kind']).to eq('puppetlabs.tasks/command-error')
      expect(result.error_hash['details']).to include({ 'file' => '/jacko/lantern', 'line' => 6 })
    end
  end

  describe :for_upload do
    it 'creates a result with an upload message' do
      t = Bolt::Inventory.empty.get_target('myhost')
      result = Bolt::Result.for_upload(t, '/local/file', '/remote/path')
      expect(result.action).to eq('upload')
      expect(result.message).to match(/Uploaded/)
    end
  end

  describe :for_download do
    it 'creates a result with a download message and path value' do
      t = Bolt::Inventory.empty.get_target('myhost')
      result = Bolt::Result.for_download(t, '/remote/file', '/local/dir', '/local/dir/file')
      expect(result.action).to eq('download')
      expect(result.value['path']).to eq('/local/dir/file')
      expect(result.message).to match(/Downloaded/)
    end
  end

  describe :for_lookup do
    it 'creates a lookup result with value and key' do
      result = Bolt::Result.for_lookup(target, 'mykey', 'myvalue')
      expect(result.action).to eq('lookup')
      expect(result.object).to eq('mykey')
      expect(result.value).to eq('value' => 'myvalue')
    end
  end

  describe :from_asserted_args do
    it 'creates a result from a target and value' do
      result = Bolt::Result.from_asserted_args(target, { 'key' => 'val' })
      expect(result.value).to eq('key' => 'val')
    end
  end

  describe :class_pcore_init_from_hash do
    it 'raises when called on the class' do
      expect { Bolt::Result._pcore_init_from_hash }
        .to raise_error(RuntimeError, /Result shouldn't be instantiated/)
    end
  end

  describe :_pcore_init_from_hash do
    it 'initializes from a hash with string keys' do
      result = Bolt::Result.new(target)
      result._pcore_init_from_hash('target' => 'bar', 'message' => 'hello')
      expect(result.message).to eq('hello')
    end
  end

  describe :_pcore_init_hash do
    it 'returns a hash representation' do
      result = Bolt::Result.new(target, message: 'hi', action: 'task', object: 'obj')
      h = result._pcore_init_hash
      expect(h['target']).to eq(target)
      expect(h['message']).to eq('hi')
    end
  end

  describe '#message?' do
    it 'returns a falsey value when message is nil' do
      expect(Bolt::Result.new(target).message?).to be_falsey
    end

    it 'returns false when message is only whitespace' do
      expect(Bolt::Result.new(target, message: "  \n").message?).to be false
    end

    it 'returns true when message has content' do
      expect(Bolt::Result.new(target, message: 'hello').message?).to be true
    end
  end

  describe '#eql?' do
    it 'returns true for results with equal target and value' do
      a = Bolt::Result.new(target, message: 'hi')
      b = Bolt::Result.new(target, message: 'hi')
      expect(a).to eq(b)
    end

    it 'returns false for results with different values' do
      a = Bolt::Result.new(target, message: 'hi')
      b = Bolt::Result.new(target, message: 'bye')
      expect(a).not_to eq(b)
    end
  end

  describe '#[]' do
    it 'provides hash-style access to the value' do
      result = Bolt::Result.new(target, message: 'hello')
      expect(result['_output']).to eq('hello')
    end
  end

  describe '#error' do
    it 'returns a Puppet error when error_hash is present' do
      puppet_error = double('puppet_error')
      error_klass = double('Puppet::DataTypes::Error', from_asserted_hash: puppet_error)
      stub_const('Puppet::DataTypes::Error', error_klass)
      result = Bolt::Result.new(target, error: { 'kind' => 'bolt/test', 'msg' => 'fail', 'details' => {} })
      expect(result.error).to be(puppet_error)
    end
  end

  describe '#to_s' do
    it 'returns a JSON string' do
      t = Bolt::Target.new('myhost')
      result = Bolt::Result.new(t, message: 'hi', action: 'task')
      expect(JSON.parse(result.to_s)['status']).to eq('success')
    end
  end

  describe :for_task do
    it 'parses json objects' do
      obj = { "key" => "val" }
      result = Bolt::Result.for_task(target, obj.to_json, '', 0, 'atask', ['/do/not/print', 8])
      expect(result.value).to eq(obj)
    end

    it 'adds an error message if _error is missing a msg' do
      obj = { '_error' => 'oops' }
      result = Bolt::Result.for_task(target, obj.to_json, '', 0, 'atask', ['/pumpkin/patch', 10])
      expect(result.error_hash['msg']).to match(/Invalid error returned from task atask/)
      expect(result.error_hash['details']).to include({ 'original_error' => 'oops',
                                                        'file' => '/pumpkin/patch',
                                                        'line' => 10 })
    end

    it 'adds kind and details to _error hash if missing' do
      obj = { '_error' => { 'msg' => 'oops' } }
      # Ensure we don't add file and line if they aren't available
      result = Bolt::Result.for_task(target, obj.to_json, '', 0, 'atask', [])
      expect(result.error_hash).to eq(
        'msg'     => 'oops',
        'kind'    => 'bolt/error',
        'details' => {}
      )
    end

    it 'marks _sensitive values as sensitive' do
      obj = { "user" => "someone", "_sensitive" => { "password" => "sosecretive" } }
      result = Bolt::Result.for_task(target, obj.to_json, '', 0, 'atask', [])
      expect(result.sensitive).to be_a(Puppet::Pops::Types::PSensitiveType::Sensitive)
      expect(result.sensitive.unwrap).to eq('password' => 'sosecretive')
    end

    it 'to_data serializes _sensitve output' do
      obj = { "user" => "someone", "_sensitive" => { "password" => "sosecretive" } }
      result = Bolt::Result.for_task(Bolt::Target.new('foo'), obj.to_json, '', 0, 'atask', [])
      serialzed = result.to_data
      expect(serialzed['value']['_sensitive']).to eq("Sensitive [value redacted]")
    end

    it 'excludes _output and _error from generic_value' do
      obj = { "key" => "val" }
      special = { "_error" => { 'msg' => 'oops' }, "_output" => "output" }
      result = Bolt::Result.for_task(target, obj.merge(special).to_json, '', 0, 'atask', [])
      expect(result.generic_value).to eq(obj)
    end

    it 'includes _sensitive in generic_value' do
      obj = { "user" => "someone", "_sensitive" => { "password" => "sosecretive" } }
      result = Bolt::Result.for_task(target, obj.to_json, '', 0, 'atask', [])
      expect(result.generic_value.keys).to include('user', '_sensitive')
    end

    it "doesn't parse arrays" do
      stdout = '[1, 2, 3]'
      result = Bolt::Result.for_task(target, stdout, '', 0, 'atask', [])
      expect(result.value).to eq('_output' => stdout)
    end

    it 'handles errors' do
      obj = { "key" => "val",
              "_error" => { "msg" => "oops", "kind" => "error", "details" => {} } }
      result = Bolt::Result.for_task(target, obj.to_json, '', 1, 'atask', [])
      expect(result.value).to eq(obj)
      expect(result.error_hash).to eq(obj['_error'])
    end

    it 'uses the unparsed value of stdout if it is not valid JSON' do
      stdout = 'just some string'
      result = Bolt::Result.for_task(target, stdout, '', 0, 'atask', [])
      expect(result.value).to eq('_output' => 'just some string')
    end

    it 'generates an error for binary data' do
      stdout = "\xFC].\xF9\xA8\x85f\xDF{\x11d\xD5\x8E\xC6\xA6"
      result = Bolt::Result.for_task(target, stdout, '', 0, 'atask', [])
      expect(result.value.keys).to eq(['_error'])
      expect(result.error_hash['msg']).to match(/The task result contained invalid UTF-8/)
    end

    it 'generates an error for non-UTF-8 output' do
      stdout = "☃".encode('utf-32')
      result = Bolt::Result.for_task(target, stdout, '', 0, 'atask', [])
      expect(result.value.keys).to eq(['_error'])
      expect(result.error_hash['msg']).to match(/The task result contained invalid UTF-8/)
    end

    it 'creates an error message for non-zero exit with empty stdout and stderr' do
      result = Bolt::Result.for_task(target, '', '', 1, 'atask', [])
      expect(result.error_hash['msg']).to match(/no output/)
    end

    it 'creates an error message for non-zero exit with empty stdout but non-empty stderr' do
      result = Bolt::Result.for_task(target, '', 'error on stderr', 1, 'atask', [])
      expect(result.error_hash['msg']).to match(/no stdout.*stderr/)
    end

    it 'creates an error message for non-zero exit with non-empty stdout' do
      result = Bolt::Result.for_task(target, '{"status":"bad"}', '', 1, 'atask', [])
      expect(result.error_hash['msg']).to match(/exit code 1/)
    end
  end
end
