# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :document do
    title "MyText"
    content "MyText"
    shared false
    owner_id 1
  end
end
