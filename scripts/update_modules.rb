#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'

# Class for parsing the Puppetfile
#
class PuppetfileParser
  attr_reader :local_modules, :modules

  def initialize
    @modules = []
  end

  def forge(_forge); end

  def moduledir(_moduledir); end

  def mod(name, args)
    if args.is_a?(String)
      @modules << [name, args]
    end
  end
end

parser = PuppetfileParser.new.tap do |puppetfile|
  contents = File.read(File.expand_path('../Puppetfile', __dir__))
  puppetfile.instance_eval(contents)
end

uri = URI('https://forgeapi.puppet.com')

Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
  parser.modules.each do |name, version|
    response = http.get("/v3/modules/#{name}")

    next unless response.is_a?(Net::HTTPOK)
    latest_version = JSON.parse(response.body).dig('current_release', 'version')

    if version != latest_version
      warn("Upgrade #{name} to #{latest_version}")
    end
  end
end
