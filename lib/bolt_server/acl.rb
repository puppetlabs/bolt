# frozen_string_literal: true

require 'rails/auth/rack'

module BoltServer
  class ACL < Rails::Auth::ErrorPage::Middleware
    class X509Matcher
      def initialize(options)
        @options = options.freeze
      end

      def match(env)
        certificate = Rails::Auth::X509::Certificate.new(env['puma.peercert'])
        # This can be extended fairly easily to search OpenSSL::X509::Certificate#extensions for subjectAltNames.
        @options.all? { |name, value| certificate[name] == value }
      end
    end

    def initialize(app, whitelist)
      acls = []
      whitelist.each do |entry|
        acls << {
          'resources' => [
            {
              'method' => 'ALL',
              'path' => '/.*'
            }
          ],
          'allow_x509_subject' => {
            'cn' => entry
          }
        }
      end
      acl = Rails::Auth::ACL.new(acls, matchers: { allow_x509_subject: X509Matcher })
      mid = Rails::Auth::ACL::Middleware.new(app, acl: acl)
      super(mid, page_body: 'Access denied')
    end
  end
end
