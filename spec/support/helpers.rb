require_relative 'helpers/session_helpers'
require_relative 'helpers/url_helpers'

RSpec.configure do |config|
  config.include Features::SessionHelpers, type: :feature
  config.include Features::UrlHelpers, type: :feature
end
