#!/usr/bin/env ruby
# frozen_string_literal: true

require 'octokit'

class ChangelogGenerator
  attr_reader :version, :entries

  def initialize(version)
    unless version
      warn "Usage: generate_changelog.rb VERSION"
      exit 1
    end

    @version = version
    @entries = {
      'feature'     => { name: 'New features', entries: [] },
      'bug'         => { name: 'Bug fixes',    entries: [] },
      'deprecation' => { name: 'Deprecations', entries: [] },
      'removal'     => { name: 'Removals',     entries: [] }
    }

    # Setting the changelog path early lets us check that it exists
    # before we spend time making API calls
    changelog
  end

  def labels
    @entries.keys
  end

  def client
    unless @client
      unless ENV['GITHUB_TOKEN']
        warn "Missing GitHub personal access token. Set $GITHUB_TOKEN with a "\
             "personal access token to use this script."
        exit 1
      end

      Octokit.configure do |c|
        c.auto_paginate = true
      end

      @client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
    end

    @client
  end

  def latest
    @latest ||= client.tags('puppetlabs/bolt').first.name
  end

  def commits
    @commits ||= client.compare('puppetlabs/bolt', latest, 'master').commits
  end

  def org_members
    @org_members ||= Set.new(client.org_members('puppetlabs').map(&:login))
  end

  def changelog
    unless @changelog
      @changelog = File.expand_path('CHANGELOG.md', Dir.pwd)

      unless File.file?(@changelog)
        warn "Unable to find changelog at #{@changelog}"
        exit 1
      end
    end

    @changelog
  end

  # Parses individual commits by searching for a !label, normalizing it to a
  # valid entry key, and pulling out the changelog entry from the commit
  def parse_commit(commit)
    regex = /!(?<label>#{labels.join('|')})(?<entry>[\s\S]*)\z/
    match = commit.commit.message.match(regex)

    add_entry(match, commit) if match
  end

  # Adds valid entries to the list of entries, adding extra information about
  # the author and whether it is an internal contribution
  def add_entry(match, commit)
    label = match[:label]

    entries[label][:entries].push(
      body:     match[:entry],
      author:   commit.commit.author.name || commit.author.login,
      profile:  commit.author.html_url,
      internal: org_members.include?(commit.author.login)
    )
  end

  def update_changelog
    old_lines = File.read(changelog).split("\n")[2..-1]

    new_lines = [
      "# Changelog\n",
      "## Bolt #{version} (#{Time.now.strftime '%Y-%m-%d'})\n"
    ]

    entries.each_value do |type|
      next unless type[:entries].any?
      new_lines << "### #{type[:name]}\n"

      type[:entries].each do |entry|
        new_lines << "#{entry[:body].strip}\n"

        unless entry[:internal]
          new_lines << "  _Contributed by [#{entry[:author]}](#{entry[:profile]})_\n"
        end
      end
    end

    content = (new_lines + old_lines).join("\n")

    if File.write(changelog, content)
      puts "Successfully wrote entries to #{changelog}"
    else
      warn "Unable to write entries to #{changelog}"
      exit 1
    end
  end

  def generate
    puts "Loading and parsing commits for #{latest}..master"

    commits.each do |commit|
      parse_commit(commit)
    end

    if entries.each_value.all? { |type| type[:entries].empty? }
      warn "No release notes for #{latest}..master"
      exit 0
    end

    update_changelog
  end
end

if $PROGRAM_NAME == __FILE__
  ChangelogGenerator.new(ARGV.first).generate
end
