source 'https://rubygems.org'
ruby '2.1.2'
gem 'rails', '~> 4.2.7.1'
gem 'sass-rails', '~> 4.0.5'
gem 'uglifier', '~> 2.7.2'
gem 'coffee-rails', '~> 4.0.0'
gem 'jquery-rails', '~> 3.1.3'
gem 'jbuilder', '~> 2.0'
gem 'sdoc', '~> 0.4.0',          group: :doc
gem 'spring',        group: :development
gem 'devise', '~> 3.5.10'
gem 'haml-rails'
gem 'pg'
gem 'unicorn'
gem 'unicorn-rails'
gem 'unicorn-worker-killer', require: false
gem 'gctools', require: false
gem 'rails_12factor', group: :production
gem 'rails-settings-cached'
gem 'cancancan', '~> 1.9'
gem 'omniauth', '~> 1.3.2'
gem 'omniauth-oauth2'
gem 'rack-cors', '~> 0.4.1', :require => 'rack/cors'
gem 'foundation-rails'
gem 'simple_form'
gem 'newrelic_rpm'
gem 'exception_notification'
gem 'addressable', :require => 'addressable/uri'
gem 'json-patch'
gem 'will_paginate'
gem 'will_paginate-foundation'
gem 'progress'
gem 'oj' # a faster json library
gem 'oj_mimic_json'  # use the oj lib *everywhere* when dealing with json

# Explicitly set some dependent gems versions because of vulns.
gem 'nokogiri', '~> 1.8.3'
gem 'ffi', '~> 1.9.24'
gem 'rubyzip', '~> 1.2.1'
gem 'sprockets', '~> 2.12.5'

gem 'rack-secure_samesite_cookies',
  :git => 'git://github.com/concord-consortium/secure-samesite-cookies',
  :tag => 'v1.0.2'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller', :platforms=>[:mri_21]
  gem 'guard-bundler'
  gem 'guard-rails'
  gem 'guard-rspec'
  gem 'html2haml'
  gem 'quiet_assets'
  gem 'rails_layout'
  gem 'rb-fchange', :require=>false
  gem 'rb-fsevent', :require=>false
  gem 'rb-inotify', :require=>false
end
group :development, :test do
  gem 'factory_girl_rails'
  gem 'rspec', '~> 3.6.0'
  gem 'rspec-rails', '~> 3.6.0'
end
group :test do
  gem 'capybara'
  gem 'database_cleaner'
  gem 'faker'
  gem 'launchy'
  gem 'selenium-webdriver'
end
