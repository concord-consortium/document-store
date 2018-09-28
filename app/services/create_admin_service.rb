class CreateAdminService
  def call
    user = User.find_or_create_by!(email: Settings.admin_email) do |user|
        user.password = Settings.admin_password
        user.password_confirmation = Settings.admin_password
        user.username = Settings.admin_username
        user.name = Settings.admin_name
        user.confirm
      end
  end
end
