# frozen_string_literal: true

require 'bolt/puppetdb/client'
require 'bolt/puppetdb/config'

module BoltSpec
  module PuppetDB
    def pdb_conf
      spec_dir = File.join(__dir__, '..', '..')
      ssl_dir = File.join(spec_dir, 'fixtures', 'ssl')
      {
        'cert' => File.join(ssl_dir, "cert.pem"),
        'key' => File.join(ssl_dir, "key.pem"),
        'cacert' => File.join(ssl_dir, "ca.pem"),
        'server_urls' => 'https://localhost:18081',
        'token' => nil
      }
    end

    def make_command(command:, version:, payload:, wait: nil)
      client = pdb_client
      url = "#{client.instance.uri}/pdb/cmd/v1"
      url += "?secondsToWaitForCompletion=#{wait}" if wait

      body = { command: command, version: version, payload: payload }
      body = JSON.generate(body)

      headers = { "Content-Type" => "application/json" }

      client.instance.http_client.post(url, body: body, header: headers)
    end

    def replace_facts(certname, facts, wait: nil)
      make_command(command: 'replace facts', version: 5, payload: {
                     certname: certname,
                     environment: 'production',
                     producer_timestamp: Time.now.iso8601(3),
                     producer: 'bolt',
                     values: facts
                   },
                   wait: wait)
    end

    def deactivate_node(certname, wait: nil)
      make_command(command: 'deactivate node', version: 3, payload: {
                     certname: certname,
                     producer_timestamp: Time.now.iso8601(3)
                   },
                   wait: wait)
    end

    def push_facts(facts_hash)
      facts_hash.each { |certname, facts| replace_facts(certname, facts, wait: 30) }
    end

    def clear_facts(facts_hash)
      facts_hash.each_key { |certname| deactivate_node(certname, wait: 30) }
    end

    def pdb_client
      Bolt::PuppetDB::Client.new(config: pdb_conf)
    end
  end
end
