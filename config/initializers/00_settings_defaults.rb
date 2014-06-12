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
Settings.defaults['mailer_delivery_method']            = ENV['MAILER_DELIVERY_METHOD']            || :file
Settings.defaults['mailer_smtp_user_name']             = ENV['MAILER_SMTP_USER_NAME']             || 'user'
Settings.defaults['mailer_smtp_password']              = ENV['MAILER_SMTP_PASSWORD']              || 'password'
Settings.defaults['mailer_smtp_authentication_method'] = ENV['MAILER_SMTP_AUTHENTICATION_METHOD'] || 'plain'
Settings.defaults['mailer_smtp_port']                  = ENV['MAILER_SMTP_PORT'].to_i             || 587
Settings.defaults['mailer_smtp_starttls_auto']         = ENV['MAILER_SMTP_STARTTLS_AUTO'].nil? ? true : ENV['MAILER_SMTP_STARTTLS_AUTO']
