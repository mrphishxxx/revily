# == Schema Information
#
# Table name: events
#
#  id                         :integer          not null, primary key
#  message                    :text
#  description                :text
#  details                    :text
#  state                      :string(255)
#  key                        :string(255)
#  current_user_id            :integer
#  current_escalation_rule_id :integer
#  escalation_loop_count      :integer          default(0)
#  uuid                       :string(255)      not null
#  service_id                 :integer
#  acknowledged_at            :datetime
#  resolved_at                :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#

class Event < ActiveRecord::Base
  include Identifiable
  include ActiveModel::ForbiddenAttributesProtection

  hound actions: [ :create, :update, :trigger, :acknowledge, :resolve ]

  serialize :details, JSON

  belongs_to :service
  belongs_to :current_user, class_name: 'User'
  belongs_to :current_escalation_rule, class_name: 'EscalationRule'
  has_many :alerts

  validates :message, presence: true
  validates :service, existence: true

  # validates :message,
  #   uniqueness: { scope: [ :service_id, :state ] },
  #   on: :create,
  #   unless: :key?

  # on: :save
  # validates :key,
  #   # uniqueness: { scope: [ :service_id, :state, :uuid ] },
  #   uniqueness: { scope: [ :service_id, :state ] },
  #   allow_nil: true,
  #   allow_blank: true,
  #   on: :create

  before_save :ensure_key
  before_create :associate_current_escalation_rule
  before_create :associate_current_user

  scope :unresolved, where("state != 'resolved'")

  def self.first_or_initialize_by_key_or_message(params)
    if params[:key]
      where(key: params[:key])
    elsif params[:message]
      where(message: params[:message])
    end.first_or_initialize(params)
  end

  def self.find_by_key_or_message(params)
    if params[:key]
      where(key: params[:key])
    elsif params[:message]
      where(message: params[:message])
    end.last
  end

  state_machine initial: :triggered do
    state :triggered do
      validate :escalation_loop_limit_not_reached
    end
    state :acknowledged
    state :resolved

    event :trigger do
      transition [ :acknowledged ] => :triggered
    end

    event :acknowledge do
      transition [ :triggered ] => :acknowledged
    end

    event :escalate do
      transition [ :triggered, :acknowledged ] => :triggered
    end

    event :resolve do
      transition [ :triggered, :acknowledged ] => :resolved
    end

    before_transition triggered: :acknowledged, do: :update_acknowledged_at
    before_transition triggered: :resolved, do: [ :update_acknowledged_at, :update_resolved_at ]
    before_transition acknowledged: :resolved, do: :update_resolved_at
    before_transition on: :escalate, do: :escalate_to_next_escalation_rule
  end

  def key_or_uuid
    self.key || self.uuid
  end

  def triggered_at
    self.created_at
  end

  protected

  # def escalation_loop_limit_reached?
  def escalation_loop_limit_not_reached
    if escalation_policy && escalation_policy.escalation_loop_limit <= self.escalation_loop_count
      errors.add(:state, 'cannot escalate when the event has has reached the escalation loop limit')
    end
  end

  private

  def ensure_key
    self[:key] ||= SecureRandom.hex
  end

  def update_resolved_at
    self[:resolved_at] = Time.zone.now
  end

  def update_acknowledged_at
    self[:acknowledged_at] = Time.zone.now
  end

  def fire_alerts!
    AlertWorker.perform_async(self.id)
  end

  def associate_current_escalation_rule
    self.current_escalation_rule = next_escalation_rule
  end

  def associate_current_user
    self.current_user = self.current_escalation_rule.assignee
  end

  def escalation_policy
    service.try(:escalation_policy)
  end

  def next_escalation_rule
    self.current_escalation_rule.try(:lower_item) || escalation_policy.escalation_rules.first
  end

  def escalate_to_next_escalation_rule    
    self[:escalation_loop_count] += 1 if next_escalation_rule.first?

    associate_current_escalation_rule
    associate_current_user
  end

end
