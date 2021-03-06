require "spec_helper"

def stub_rule
  allow(subject).to receive(:assignment_attributes) { { id: user.uuid, type: "User" } }
  allow(subject).to receive(:policy) { policy }
end

describe PolicyRule do
  pause_events!
  
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:schedule) { create(:schedule, account: account) }
  let(:policy) { create(:policy, account: account) }

  context "associations" do
    before { stub_rule }

    it { expect(subject).to belong_to(:policy) }
    it { expect(subject).to belong_to(:assignment) }
  end

  context "validations" do
    before { stub_rule }

    it { expect(subject).to validate_presence_of(:escalation_timeout) }
  end

  context "attributes" do
    before { stub_rule }

    it { expect(subject).to have_readonly_attribute(:uuid) }

    it "sets to_param to uuid" do
      obj = build(:policy_rule, policy: policy)
      obj.save(:validate => false)
      expect(obj.to_param).to eq obj.uuid
    end
  end

  context "#assignment_attributes=" do
    it "finds and associates the appropriate user" do
      policy_rule = build(:policy_rule, policy: policy, assignment_attributes: { id: user.uuid, type: "User" })
      policy_rule.save
      expect(policy_rule.assignment_type).to eq "User"
      expect(policy_rule.assignment_id).to eq user.id
    end

    it "finds and associates the appropriate schedule" do
      policy_rule = build(:policy_rule, policy: policy, assignment_attributes: { id: schedule.uuid, type: "Schedule" })
      policy_rule.save
      expect(policy_rule.assignment_type).to eq "Schedule"
      expect(policy_rule.assignment_id).to eq schedule.id
    end

  end
end
