require "rails_helper"

RSpec.describe OrderDetail do
  let(:instrument) { FactoryGirl.create(:instrument_with_accessory, :not_reservation_only) }
  let(:accessory) { instrument.accessories.first }
  let(:reservation) { FactoryGirl.create(:completed_reservation, product: instrument) }
  let(:order_detail) { reservation.order_detail }
  let(:accessorizer) { Accessories::Accessorizer.new(order_detail) }

  before :each do
    order_detail.backdate_to_complete!(Time.zone.now)
  end

  shared_examples_for "an accessory's order detail" do
    it "belongs to the parent" do
      expect(accessory_order_detail.parent_order_detail).to eq(order_detail)
    end

    it "belongs to the same order" do
      expect(accessory_order_detail.order).to eq(order_detail.order)
    end

    it "is for the correct product" do
      expect(accessory_order_detail.product).to eq(accessory)
    end

    it "is for the same account" do
      expect(accessory_order_detail.account).to eq(order_detail.account)
    end

    it "is complete" do
      expect(accessory_order_detail).to be_complete
      expect(accessory_order_detail.order_status.name).to eq("Complete")
    end

    it "has pricing" do
      expect(accessory_order_detail.actual_cost).to be
    end

    it "changes the child's account when changing the parent's account" do
      new_account = FactoryGirl.create(:setup_account, owner: order_detail.user)
      order_detail.update_attributes(account: new_account)
      expect(accessory_order_detail.reload.account).to eq new_account
    end
  end

  context "quantity based accessory" do
    let!(:accessory_order_detail) { accessorizer.add_accessory(accessory) }
    it_behaves_like "an accessory's order detail"

    context "where the reservation time changes" do
      before :each do
        accessory_order_detail.update_attributes(quantity: 1)
        reservation.update_attributes(reserve_end_at: reservation.reserve_end_at + 30.minutes)
      end

      it "does not update the quantity" do
        expect(accessory_order_detail.reload.quantity).to eq(1)
      end
    end
  end

  context "manual scaled accessory" do
    let(:accessory_order_detail) { accessorizer.add_accessory(accessory) }
    before :each do
      accessorizer.send(:product_accessory, accessory).update_attributes!(scaling_type: "manual")
      accessory_order_detail # load
    end

    it_behaves_like "an accessory's order detail"

    it "has the number of actual usage time as the quantity" do
      expect(accessory_order_detail.quantity).to eq(reservation.actual_duration_mins)
    end

    skip "defaults to 1 if less than a minute" do
      reservation.update_attributes(actual_end_at: reservation.actual_start_at + 30.seconds)
      expect(reservation.actual_duration_mins).to eq(0)
      expect(accessory_order_detail.reload.quantity).to eq(1)
    end

    context "where the reservation time changes" do
      before :each do
        accessory_order_detail.update_attributes(quantity: 1)
        reservation.update_attributes(reserve_end_at: reservation.reserve_end_at + 30.minutes)
      end

      it "does not update the quantity" do
        expect(accessory_order_detail.reload.quantity).to eq(1)
      end
    end

    context "where the actual time changes" do
      before :each do
        accessory_order_detail.update_attributes(quantity: 1)
        reservation.update_attributes(actual_end_at: reservation.actual_end_at + 30.minutes)
      end

      it "does not update the quantity" do
        expect(accessory_order_detail.reload.quantity).to eq(1)
      end
    end
  end

  context "auto scaled accessory" do
    # reload in order to avoid timestamp truncation causing false-positives on `changes`
    let(:accessory_order_detail) { accessorizer.add_accessory(accessory).reload }
    before :each do
      accessorizer.send(:product_accessory, accessory).update_attributes(scaling_type: "auto")
      accessory_order_detail # load
    end

    it_behaves_like "an accessory's order detail"

    it "has the number of actual usage time as the quantity" do
      expect(accessory_order_detail.quantity).to eq(reservation.actual_duration_mins)
    end

    skip "defaults to 1 if less than a minute" do
      reservation.update_attributes(actual_end_at: reservation.actual_start_at + 30.seconds)
      expect(reservation.actual_duration_mins).to eq(0)
      expect(accessory_order_detail.reload.quantity).to eq(1)
    end

    context "where the reservation time changes" do
      before :each do
        reservation.update_attributes(reserve_end_at: reservation.reserve_end_at + 30.minutes)
      end

      it "does not update the quantity" do
        expect(accessory_order_detail.reload.quantity).to eq(60)
      end

      it "does not mark anything as changed" do
        expect(order_detail.updated_children).to be_empty
      end
    end

    context "where the actual time changes" do
      before :each do
        reservation.update_attributes(actual_end_at: reservation.actual_end_at + 30.minutes)
      end

      it "updates the quantity" do
        expect(accessory_order_detail.reload.quantity).to eq(90)
      end

      it "marks as changed" do
        # accessory_order_detail might be decorated at this point, so reload
        expect(order_detail.updated_children).to eq([accessory_order_detail.reload])
      end
    end
  end

  context "accessory does not have a price policy" do
    let(:accessory_order_detail) { accessorizer.add_accessory(accessory) }
    before :each do
      accessory.price_policies.destroy_all
    end

    it "makes the order detail complete" do
      expect(accessory_order_detail.order_status.name).to eq("Complete")
    end

    it "makes the order detail a problem order" do
      expect(accessory_order_detail).to be_problem_order
    end
  end
end
