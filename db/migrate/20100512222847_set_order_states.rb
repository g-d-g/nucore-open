class SetOrderStates < ActiveRecord::Migration

  def self.up
    Order.where(ordered_at: nil).update_all(state: "new")
    Order.where("ordered_at IS NOT NULL").update_all(state: "purchased")
  end

  def self.down
    Order.update_all(state: nil)
  end

end
