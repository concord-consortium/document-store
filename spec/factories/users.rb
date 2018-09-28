FactoryGirl.define do
  factory :user do
    name "Test User"
    email { "#{username}@example.com".downcase }
    password "please123"
    username "test"
    after(:create) {|u| u.confirm rescue nil }
  end
end
