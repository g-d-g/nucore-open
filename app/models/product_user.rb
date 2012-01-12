class ProductUser < ActiveRecord::Base
  belongs_to :user
  belongs_to :product
  belongs_to :instrument_restriction_level
  
  validates_numericality_of :product_id, :user_id, :approved_by, :only_integer => true
  validates_uniqueness_of :user_id, :scope => :product_id, :message => 'is already approved'

  before_create lambda { |pu| pu.approved_at = Time.zone.now }
end