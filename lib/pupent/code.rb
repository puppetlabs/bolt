# frozen_string_literal: true

require 'json'
require_relative "../pupent/access"

module PupEnt
  class Code
    CODE_MANAGER_PREFIX = ":8170/code-manager"

    def initialize(token_location, http_client)
      @token = Access.new(token_location).show
      @client = http_client
    end

    def deploy(environments, wait, all)
      body = {}
      if all
        body["deploy-all"] = true
      else
        body[:environments] = environments.split(',')
      end

      if wait
        body[:wait] = true
      end
      response, = @client.pe_post('/v1/deploys', body, headers: { "X-Authentication": @token })
      JSON.pretty_generate(response)
    end

    def status
      response, = @client.pe_get('/v1/status', headers: { "X-Authentication": @token })
      JSON.pretty_generate(response)
    end

    def deploy_status(deploy_id)
      url_path = if deploy_id && !deploy_id.empty?
                   "/v1/deploys/status?id=#{deploy_id}"
                 else
                   "/v1/deploys/status"
                 end
      response, = @client.pe_get(url_path, headers: { "X-Authentication": @token })
      JSON.pretty_generate(response)
    end
  end
end
