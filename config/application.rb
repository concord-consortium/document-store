require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Documentstore
  class Application < Rails::Application

    config.generators do |g|
      g.test_framework :rspec,
        fixtures: true,
        view_specs: false,
        helper_specs: false,
        routing_specs: false,
        controller_specs: false,
        request_specs: false
      g.fixture_replacement :factory_girl, dir: "spec/factories"
    end

    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    config.active_record.schema_format = :sql

    config.middleware.use Rack::Deflater

    require 'rack/inflate_request'
    config.middleware.insert_before Rack::Runtime, Rack::InflateRequest

    config.middleware.insert 0, Rack::UTF8Sanitizer

    config.middleware.insert_before Warden::Manager, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, expose: ['Document-Id', 'X-Codap-Will-Overwrite', 'X-Codap-Opened-From-Shared-Document'], methods: [:get, :post, :options, :put, :patch], credentials: true
      end
    end
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Allow embedding this app within an iframe
    config.action_dispatch.default_headers['X-Frame-Options'] = 'ALLOWALL'
  end
end
