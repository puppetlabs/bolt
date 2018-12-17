# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/conn'
require 'plan_executor/app'
require 'json'
require 'rack/test'

describe "PlanExecutor::App" do
  include BoltSpec::Conn
  include Rack::Test::Methods

  let(:plan_name) { 'basic' }
  let(:params) { {} }
  let(:request) {
    {
      plan_name: plan_name,
      job_id: '1',
      params: params
    }
  }
  let(:json_req) { JSON.generate(request) }
  let(:header) { { 'CONTENT_TYPE' => 'text/json' } }

  def app
    moduledir = File.join(__dir__, '..', 'fixtures', 'plan_executor')
    PlanExecutor::App.new(moduledir)
  end

  it 'responds ok' do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.status).to eq(200)
  end

  shared_examples 'schema failure' do
    it 'fails' do
      body = request.reject { |k, _| k == missing }
      post '/plan/run', JSON.generate(body), header
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(400)
      result = JSON.parse(last_response.body)
      regex = %r{The property '#/' did not contain a required property of '#{missing}' in schema}
      expect(result['details'].join).to match(regex)
    end
  end

  context 'without a plan_name' do
    let(:missing) { :plan_name }
    include_examples 'schema failure'
  end

  context 'without a job_id' do
    let(:missing) { :job_id }
    include_examples 'schema failure'
  end

  context 'without params' do
    let(:missing) { :params }
    include_examples 'schema failure'
  end

  context 'with an unknown plan' do
    let(:plan_name) { 'basic::unknown' }

    it 'errors' do
      post '/plan/run', json_req, header
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(500)
      result = JSON.parse(last_response.body)
      expect(result['msg']).to match(/Could not find a plan named "#{plan_name}"/)
    end
  end

  it 'executes a plan' do
    post '/plan/run', json_req, header
    expect(last_response).to be_ok
    expect(last_response.status).to eq(200)
    status = JSON.parse(last_response.body)
    expect(status).to eq('status' => 'running')

    get '/plan/result'
    expect(last_response).to be_ok
    expect(last_response.body).to eq("\"Plan your execution. Execute your plan.\"")
  end

  context 'with a plan expecting parameters' do
    let(:plan_name) { 'basic::args' }

    it 'errors without parameters' do
      post '/plan/run', json_req, header
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
      status = JSON.parse(last_response.body)
      expect(status).to eq('status' => 'running')

      get '/plan/result'
      expect(last_response).to be_ok
      result = JSON.parse(last_response.body)
      expect(result['kind']).to eq("bolt/pal-error")
      expect(result['msg']).to eq("basic::args: expects a value for parameter 'msg'")
    end

    context 'with parameters' do
      let(:params) { { 'msg' => 'Peanut butter and jelly' } }
      it 'executes' do
        post '/plan/run', json_req, header
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        status = JSON.parse(last_response.body)
        expect(status).to eq('status' => 'running')

        get '/plan/result'
        expect(last_response).to be_ok
        expect(last_response.body).to eq("\"Peanut butter and jelly\"")
      end
    end
  end

  context 'with apply in a plan' do
    let(:plan_name) { 'basic::apply' }
    let(:params) { { 'nodes' => 'node1.example.com' } }

    it 'executes' do
      post '/plan/run', json_req, header
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
      status = JSON.parse(last_response.body)
      expect(status).to include('status' => 'running')

      get '/plan/result'
      expect(last_response).to be_ok
      result = JSON.parse(last_response.body)
      expect(result).to include("kind" => 'bolt.plan-executor/not-implemented')
    end
  end
end
