# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :service_policy do
    service
    policy

    after(:stub) { |model| model.send(:ensure_uuid) }

  end
end
