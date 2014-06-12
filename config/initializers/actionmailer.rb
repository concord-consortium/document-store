# ActionMailer Config
# This is in an initializer so that the Settings defaults can be correctly applied first
ActionMailer::Base.default_url_options = { :host => Settings.mailer_domain_name }
ActionMailer::Base.delivery_method = Settings.mailer_delivery_method
ActionMailer::Base.smtp_settings = {
  address: Settings.mailer_smtp_host,
  port: Settings.mailer_smtp_port,
  domain: Settings.mailer_domain_name,
  authentication: Settings.mailer_smtp_authentication_method,
  enable_starttls_auto: Settings.mailer_smtp_starttls_auto,
  user_name: Settings.mailer_smtp_user_name,
  password: Settings.mailer_smtp_password
}
