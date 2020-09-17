# frozen_string_literal: true

require 'spec_helper'
require 'bolt_server/acl'
require 'json'
require 'rack/test'

def x509_certificate(name)
  cert = OpenSSL::X509::Certificate.new
  cert.subject = OpenSSL::X509::Name.parse("/CN=#{name}")
  cert
end

describe BoltServer::ACL do
  include Rack::Test::Methods

  let(:yes_app) { ->(_) { [200, { 'Content-Type' => 'text/plain' }, ['OK']] } }
  let(:app) { described_class.new(yes_app, allowlist) }

  context 'with empty allowlist' do
    let(:allowlist) { [] }

    it 'rejects all requests' do
      get '/'
      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(403)
      expect(last_response.body).to eq('Access denied')
    end
  end

  context 'with allowlist' do
    let(:allowlist) { %w[cert1 cert2] }

    it 'accepts requests from allowlisted certs' do
      allowlist.each do |name|
        get '/', {}, 'HTTPS' => 'on', 'puma.peercert' => x509_certificate(name)

        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end
    end

    it 'rejects requests from other certs' do
      get '/', {}, 'HTTPS' => 'on', 'puma.peercert' => x509_certificate('invalid')

      expect(last_response).not_to be_ok
      expect(last_response.status).to eq(403)
    end
  end
end
