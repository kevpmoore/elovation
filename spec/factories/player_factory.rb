FactoryGirl.define do
  factory :player do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    color { 'green'}
  end
end
