# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :document do
    title "MyText"
    form_content "{}"
    shared false
    owner_id 1
  end
end
