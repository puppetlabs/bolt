# frozen_string_literal: true

# Bump the module versions in the Puppetfile to the latest version
# published on https://forge.puppet.com
require 'open-uri'
require 'pry'
require 'rss'

def parse_puppetfile_get_mod_versions
  module_re = /^mod 'puppetlabs-([a-z_\-]+)', *'([0-9.]+)'$/i
  versions = {}
  File.foreach('Puppetfile') do |line|
    match = module_re.match(line)
    if match
      versions[match[1].strip] = match[2].strip
    end
  end
  versions
end

def latest_version_for_module(mod)
  url = "https://forge.puppet.com/modules/puppetlabs/#{mod}/rss"
  # rubocop:disable Security/Open
  feed = RSS::Parser.parse(URI.open(url))
  # rubocop:enable Security/Open

  feed.items&.first&.description
end

# get modules to update
versions_old = parse_puppetfile_get_mod_versions
versions_new = {}

versions_old.each do |mod, ver|
  ver_new = latest_version_for_module(mod)

  if !ver_new.nil? && (ver != ver_new)
    versions_new[mod] = ver_new
  end
end

def puppetfile_set_mod_versions!(versions_new)
  module_re = /^mod 'puppetlabs-([a-z_\-]+)', *'([0-9.]+)'$/i
  lines = File.open('Puppetfile').readlines

  # update lines
  lines.each do |line|
    next unless line.start_with?("mod 'puppetlabs")
    match = module_re.match(line)
    next unless match
    mod = match[1].strip
    ver_old = match[2].strip
    ver_new = versions_new[mod]
    unless ver_new.nil?
      line.gsub!(/'([0-9.]+)'/, "'#{ver_new}'")
      puts "Updated #{mod} from #{ver_old} to #{ver_new}"
    end
  end

  # update Puppetfile
  File.open('Puppetfile', 'w').puts(lines.join)
end

# Update the Puppetfile with the new versions
puppetfile_set_mod_versions!(versions_new)
