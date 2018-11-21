# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/bolt_server'
require 'bolt_server/plan_app'
require 'json'
require 'rack/test'

describe "BoltServer::TransportApp" do
  include BoltSpec::BoltServer
  include Rack::Test::Methods

  let(:path) { '/plan/run' }
  let(:plan_name) { 'basic' }
  let(:params) { {} }
  let(:request) {
    {
      plan_name: plan_name,
      job_id: '1',
      params: params
    }
  }

  def app
    moduledir = File.join(__dir__, '..', 'fixtures', 'plan_server')
    BoltServer::PlanApp.new(moduledir)
  end

  before(:each) do
    post '/plan/result'
  end

  it 'responds ok' do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.status).to eq(200)
  end

  shared_examples 'schema failure' do
    it 'fails' do
      body = request.reject { |k, _| k == missing }
      post path, JSON.generate(body), 'CONTENT_TYPE' => 'text/json'
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
      post path, JSON.generate(request), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(500)
      result = JSON.parse(last_response.body)
      expect(result['msg']).to match(/Could not find a plan named "#{plan_name}"/)
    end
  end

  it 'executes a plan' do
    post path, JSON.generate(request), 'CONTENT_TYPE' => 'text/json'
    expect(last_response).to be_ok
    expect(last_response.status).to eq(200)
    status = JSON.parse(last_response.body)
    expect(status).to eq('status' => 'running')

    get '/plan/result'
    expect(last_response).to be_ok
    expect(last_response.body).to be_empty
  end

  context 'with a plan expecting parameters' do
    let(:plan_name) { 'basic::args' }

    it 'errors without parameters' do
      post path, JSON.generate(request), 'CONTENT_TYPE' => 'text/json'
      expect(last_response).to be_ok
      expect(last_response.status).to eq(200)
      status = JSON.parse(last_response.body)
      expect(status).to eq('status' => 'running')

      get '/plan/result'
      expect(last_response).to be_ok
      # TODO: this shouldn't be empty, it should be an error
      expect(last_response.body).to be_empty
    end

    context 'with parameters' do
      let(:params) { { 'msg' => 'Goodbye' } }
      it 'executes' do
        post path, JSON.generate(request), 'CONTENT_TYPE' => 'text/json'
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
        status = JSON.parse(last_response.body)
        expect(status).to eq('status' => 'running')

        get '/plan/result'
        expect(last_response).to be_ok
        expect(last_response.body).to eq('Goodbye')
      end
    end
  end
end
