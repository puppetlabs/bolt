# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'apply::resource task' do
  describe 'managing packages' do
    it 'installs pry' do
      params = { type: 'package', title: 'pry', parameters: { provider: 'puppet_gem', ensure: 'present' } }
      output = run_task(task_name: 'apply::resource', format: 'json', params: params)

      result = output['result']

      expect(result['type']).to eq('package')
      expect(result['title']).to eq('pry')
      expect(result['changed']).to eq(true)

      change = result['changes'].first
      expect(change['property']).to eq('ensure')
      expect(change['previous_value']).to eq('absent')
      expect(change['desired_value']).to eq('present')
    end

    it 'uninstalls pry' do
      params = { type: 'package', title: 'pry', parameters: { provider: 'puppet_gem', ensure: 'absent' } }
      output = run_task(task_name: 'apply::resource', format: 'json', params: params)

      result = output['result']

      expect(result['type']).to eq('package')
      expect(result['title']).to eq('pry')
      expect(result['changed']).to eq(true)

      change = result['changes'].first
      expect(change['property']).to eq('ensure')
      expect(change['desired_value']).to eq('absent')
    end
  end

  describe 'managing files' do
    it 'creates the file' do
      params = { type: 'file', title: '/tmp/testfile', parameters: { content: 'hello world' } }
      output = run_task(task_name: 'apply::resource', format: 'json', params: params)

      result = output['result']

      expect(result['type']).to eq('file')
      expect(result['title']).to eq('/tmp/testfile')
      expect(result['changed']).to eq(true)

      change = result['changes'].first
      expect(change['property']).to eq('ensure')
      expect(change['previous_value']).to eq('absent')
      expect(change['desired_value']).to eq('file')
    end

    it 'modifies the file content' do
      params = { type: 'file', title: '/tmp/testfile', parameters: { content: 'goodbye world' } }
      output = run_task(task_name: 'apply::resource', format: 'json', params: params)

      result = output['result']

      expect(result['type']).to eq('file')
      expect(result['title']).to eq('/tmp/testfile')
      expect(result['changed']).to eq(true)

      change = result['changes'].first
      expect(change['property']).to eq('content')
    end

    it 'deletes the file' do
      params = { type: 'file', title: '/tmp/testfile', parameters: { ensure: 'absent' } }
      output = run_task(task_name: 'apply::resource', format: 'json', params: params)

      result = output['result']

      expect(result['type']).to eq('file')
      expect(result['title']).to eq('/tmp/testfile')
      expect(result['changed']).to eq(true)

      change = result['changes'].first
      expect(change['property']).to eq('ensure')
      expect(change['previous_value']).to eq('file')
      expect(change['desired_value']).to eq('absent')
    end
  end

  describe "if the resource can't be managed" do
    it 'fails with the error message' do
      params = { type: 'file', title: '/tmp/foo/bar/baz', parameters: { ensure: 'present' } }
      output = run_task(task_name: 'apply::resource', format: 'json', params: params)

      result = output['result']

      expect(result['type']).to eq('file')
      expect(result['title']).to eq('/tmp/foo/bar/baz')
      expect(result['changed']).to eq(false)

      expect(result['_error']['msg']).to match(/change from absent to present failed.*No such file or directory/)

      failure = result['failures'].first
      expect(failure['property']).to eq('ensure')
      expect(failure['previous_value']).to eq('absent')
      expect(failure['desired_value']).to eq('present')
      expect(failure['message']).to match(/change from absent to present failed.*No such file or directory/)
    end
  end

  describe "with a resource type that doesn't exist" do
    it 'fails with an error' do
      params = { type: 'nosuchtype', title: 'whatever', parameters: {} }
      output = run_task(task_name: 'apply::resource', format: 'json', params: params)

      result = output['result']

      expect(result['changed']).to eq(false)

      expect(result['_error']['msg']).to match(/Invalid resource type nosuchtype/)
      expect(result['_error']['kind']).to eq('apply/type-not-found')
    end
  end
end
