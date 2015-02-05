# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :document do
    title "MyText"
    form_content %!{"appName": "name", "appVersion": "version", "appBuildNum": 1}!
    shared false
    owner_id 1
  end
end
