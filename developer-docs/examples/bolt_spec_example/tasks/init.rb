#!/usr/bin/env ruby
# frozen_string_literal: true

File.write(ENV.fetch('PT_file', nil), ENV.fetch('PT_content', nil))
