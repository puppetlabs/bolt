# frozen_string_literal: true

module Puma
  class DSL
    def stats_url(url = nil)
      @options[:stats_url] = url
    end

    def stats_token(token = nil)
      @options[:stats_token] = token
    end
  end
end
