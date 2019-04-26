# frozen_string_literal: true

module Acceptance
  module BoltSetupHelper
    def ssh_user
      ENV['SSH_USER'] || 'root'
    end

    def ssh_password
      ENV['SSH_PASSWORD'] || 'bolt_secret_password'
    end

    def winrm_user
      ENV['WINRM_USER'] || 'Administrator'
    end

    def winrm_password
      ENV['WINRM_PASSWORD'] || 'bolt_secret_password'
    end

    def gem_version
      ENV['GEM_VERSION'] || '> 0.1.0'
    end

    def gem_source
      ENV['GEM_SOURCE'] || 'https://rubygems.org'
    end

    def git_server
      ENV['GIT_SERVER'] || 'https://github.com'
    end

    def git_fork
      ENV['GIT_FORK'] || 'puppetlabs/bolt'
    end

    def git_branch
      ENV['GIT_BRANCH'] || 'master'
    end

    def git_sha
      ENV['GIT_SHA'] || ''
    end

    def local_user
      ENV['LOCAL_USER'] || 'local_user'
    end

    def local_user_homedir
      case bolt['platform']
      when /osx/
        "/Users/#{local_user}"
      else
        "/home/#{local_user}"
      end
    end
  end
end
