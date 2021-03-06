class OrderStatus < ActiveRecord::Base

  acts_as_nested_set

  has_many :order_details
  belongs_to :facility

  validates_presence_of :name
  validates_uniqueness_of :name, scope: [:parent_id, :facility_id]
  validates_each :parent_id do |model, attr, value|
    begin
      model.errors.add(attr, "must be a root") unless value.nil? || OrderStatus.find(value).root?
    rescue => e
      model.errors.add(attr, "must be a valid root")
    end
  end

  scope :for_facility, -> (facility) { where(facility_id: [nil, facility.id]).order(:lft) }
  scope :new_os, -> { where(name: "New").limit(1) }
  scope :inprocess, -> { where(name: "In Process").limit(1) }
  scope :canceled, -> { where(name: "Canceled").limit(1) }
  scope :complete, -> { where(name: "Complete").limit(1) }
  scope :reconciled, -> { where(name: "Reconciled").limit(1) }

  def self.new_status
    new_os.first
  end

  def self.complete_status
    complete.first
  end

  def self.canceled_status
    canceled.first
  end

  def self.reconciled_status
    reconciled.first
  end

  def editable?
    !!facility
  end

  def state_name
    root.name.downcase.delete(" ").to_sym
  end

  def downcase_name
    name.downcase.gsub(/\s+/, "_")
  end

  def is_left_of?(o)
    rgt < o.lft
  end

  def is_right_of?(o)
    lft > o.rgt
  end

  def name_with_level
    "#{'-' * level} #{name}".strip
  end

  def to_s
    name
  end

  def root_canceled?
    root == OrderStatus.canceled.first
  end

  class << self

    def root_statuses
      roots.sort { |a, b| a.lft <=> b.lft }
    end

    def default_order_status
      root_statuses.first
    end

    def initial_statuses(facility)
      first_invalid_status = find_by_name("Canceled")
      statuses = all.sort { |a, b| a.lft <=> b.lft }.reject do |os|
        !os.is_left_of?(first_invalid_status)
      end
      statuses.reject! { |os| os.facility_id != facility.id && !os.facility_id.nil? } unless facility.nil?
      statuses
    end

    def non_protected_statuses(facility)
      first_protected_status = find_by_name("Reconciled")
      statuses = all.sort { |a, b| a.lft <=> b.lft }.reject do |os|
        !os.is_left_of?(first_protected_status)
      end
      statuses.reject! { |os| os.facility_id != facility.id && !os.facility_id.nil? } unless facility.nil?
      statuses
    end

  end

end
