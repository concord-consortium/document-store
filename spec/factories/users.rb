FactoryGirl.define do
  factory :user do
    name "Test User"
    email "test@example.com"
    password "please123"
    username "test"
    after(:create) {|u| u.confirm! rescue nil }
  end
end
