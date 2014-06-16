include Warden::Test::Helpers
Warden.test_mode!

# Feature: User index page
#   As a user
#   I want to see a list of users
#   So I can see who has registered
feature 'User index page', :devise do

  after(:each) do
    Warden.test_reset!
  end

  # Scenario: User listed on index page
  #   Given I am signed in
  #   When I visit the user index page
  #   Then I get a permissions error
  scenario 'user cannot see user list' do
    user = FactoryGirl.create(:user)
    login_as(user, scope: :user)
    expect {
      visit users_path
    }.to raise_error(ActiveRecord::RecordNotFound)
  end

end
