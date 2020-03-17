#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

# Parses individual notes by searching for a !label, normalizing it to a
# valid entry key, and returning both the normalized label and the changelog
# entry
def parse_commit(labels, commit)
  regex   = /!(?<label>#{labels.join('|')})(?<entry>[\s\S]*)\z/
  matches = commit.match(regex)
  [matches[:label], matches[:entry].strip] if matches
end

# Map of valid labels to their full name and list of entries.
# Any notes that do not have a valid label are ignored and not added
# to the changelog.
entries = {
  'feature'     => { name: 'New features', entries: [] },
  'bug'         => { name: 'Bug fixes',    entries: [] },
  'deprecation' => { name: 'Deprecations', entries: [] },
  'removal'     => { name: 'Removals',     entries: [] }
}

version    = ARGV.first
changelog  = File.expand_path('CHANGELOG.md', Dir.pwd)

unless version
  warn "Usage: generate_changelog.rb VERSION"
  exit 1
end

unless File.file?(changelog)
  warn "Could not find changelog at #{changelog}"
  exit 1
end

# Get the latest tag
latest = `git describe --abbrev=0`.chomp

# Read the git log between master and the most recent tagged release
# The log is formatted to only include the body of a commit and are
# terminated with a null terminator. These entries are then filtered
# to only include those that have a valid LABEL (e.g. !feature, !bug)
stdout_str, stderr_str, status = Open3.capture3(
  "git log -z HEAD...#{latest} "\
  "--pretty=format:'%b' "\
  "--grep='!(#{entries.keys.join('|')})' -E"
)

if status.success?
  # Create an array of commit messages
  commits = stdout_str.split("\u0000")

  if commits.empty?
    warn "Did not find any changelog entries"
    exit 0
  end

  # Parse the notes and map them to the correct list of entries
  commits.each do |commit|
    label, entry = parse_commit(entries.keys, commit)

    if entries.key?(label)
      entries[label][:entries] << entry
    end
  end
else
  warn stderr_str
  exit 1
end

# Build the new changelog content from the list of valid notes
new_content = <<~CONTENT
  # Changelog

  ## Bolt #{version} (#{Time.now.strftime '%Y-%m-%d'})

CONTENT

entries.each_value do |entry|
  next unless entry[:entries].any?
  new_content += <<~CONTENT
    ### #{entry[:name]}

    #{entry[:entries].join("\n\n")}
  CONTENT
end

content = new_content + File.read(changelog)
                            .split("\n")[1..-1]
                            .join("\n")

if File.write(changelog, content)
  puts "Successfully wrote entries to #{changelog}"
else
  warn "Unable to write entries to #{changelog}"
  exit 1
end
