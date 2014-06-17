Settings.class_eval do
  def self.object(var_name)
    thing_scoped.where(:var => var_name.to_s).first rescue nil
  end
end

Settings.defaults['admin_name']     = ENV['ADMIN_NAME']     || 'Admin'
Settings.defaults['admin_email']    = ENV['ADMIN_EMAIL']    || 'admin@concord.org'
Settings.defaults['admin_password'] = ENV['ADMIN_PASSWORD'] || 'password'
Settings.defaults['admin_username'] = ENV['ADMIN_USERNAME'] || 'admin'

Settings.defaults['mailer_domain_name']                = ENV['DOMAIN_NAME']                       || 'example.com'
Settings.defaults['mailer_delivery_method']            = ENV['MAILER_DELIVERY_METHOD'].nil? ? :file : ENV['MAILER_DELIVERY_METHOD'].to_sym
Settings.defaults['mailer_smtp_user_name']             = ENV['MAILER_SMTP_USER_NAME']             || 'user'
Settings.defaults['mailer_smtp_password']              = ENV['MAILER_SMTP_PASSWORD']              || 'password'
Settings.defaults['mailer_smtp_authentication_method'] = ENV['MAILER_SMTP_AUTHENTICATION_METHOD'].nil? ? :login : ENV['MAILER_SMTP_AUTHENTICATION_METHOD'].to_sym
Settings.defaults['mailer_smtp_host']                  = ENV['MAILER_SMTP_HOST']                  || 'smtp.gmail.com'
Settings.defaults['mailer_smtp_port']                  = ENV['MAILER_SMTP_PORT'].nil? ? 587 : ENV['MAILER_SMTP_PORT'].to_i
Settings.defaults['mailer_smtp_starttls_auto']         = ENV['MAILER_SMTP_STARTTLS_AUTO'].nil? ? true : ENV['MAILER_SMTP_STARTTLS_AUTO']

# Should we automatically create User objects to match the 'username' param passed in via the CODAP API?
# This should be false except in special server configurations.
Settings.defaults['create_missing_users'] = false


# Omniauth portal configurations
Settings.defaults['enable_user_registration'] = false

# Adding a new portal for authentication is as simple as defining it:
# Settings['auth.foo'] = {
#   display_name: 'Foo',
#   url: 'http://foo.portal.concord.org/',
#   client_id: 'documentstore',
#   client_secret: '1234'
# }
