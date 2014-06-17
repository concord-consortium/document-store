class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  if Settings.enable_user_registration
    devise :database_authenticatable, :registerable, :confirmable,
           :recoverable, :rememberable, :trackable, :validatable,
           :omniauthable, :omniauth_providers => Concord::AuthPortal.all_strategy_names
  else
    devise :database_authenticatable, :rememberable, :trackable,
           :omniauthable, :omniauth_providers => Concord::AuthPortal.all_strategy_names
  end

  has_many :documents, inverse_of: :owner, foreign_key: 'owner_id'
  has_many :authentications, dependent: :delete_all

  validates :username, uniqueness: true, presence: true

  def self.find_for_concord_portal_oauth(auth, signed_in_resource=nil)
    authentication = Authentication.find_by_provider_and_uid auth.provider, auth.uid
    if authentication
      # update the authentication token for this user to make sure it stays fresh
      authentication.update_attribute(:token, auth.credentials.token)
      return authentication.user
    end

    # there is no authentication for this provider and uid
    # see if we should create a new authentication for an existing user
    # or make a whole new user
    email = auth.info.email || "#{Devise.friendly_token[0,20]}@example.com"

    # the devise validatable model enforces unique emails, so no need find_all
    existing_user_by_email = User.find_by(email: email)

    if existing_user_by_email
      if existing_user_by_email.authentications.find_by_provider auth.provider
        throw "Can't have duplicate email addresses: #{email}. " +
              "There is an user with an authentication for this provider #{auth.provider} " +
              "and the same email already."
      end
      # There is no authentication for this provider and user
      user = existing_user_by_email
    else
      # no user with this email, so make a new user with a random password
      user = User.new(
        email:    email,
        username: auth.extra.username,
        name:     auth.extra.name,
        password: Devise.friendly_token[0,20]
      )
      user.skip_confirmation!
      user.save
    end
    # create new authentication for this user that we found or created
    user.authentications.create(
      provider: auth.provider,
      uid:      auth.uid,
      token:    auth.credentials.token
    )
    user
  end

end
