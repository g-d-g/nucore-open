require "rails_helper"

def define_purchasable_instrument
  @instrument    = FactoryGirl.create(:instrument,
                                      facility: @facility,
                                      facility_account: @facility_account)
  @instrument_pp = FactoryGirl.create(:instrument_price_policy, product: @instrument, price_group: @price_group)
  FactoryGirl.create(:price_group_product, product: @instrument, price_group: @price_group)
  # default rule, 9am - 5pm all days
  @rule = @instrument.schedule_rules.create(FactoryGirl.attributes_for(:schedule_rule))
  define_open_account(@instrument.account, @account.account_number)
end

RSpec.describe Order do
  let(:user) { FactoryGirl.create(:user) }
  let(:order) { user.orders.create FactoryGirl.attributes_for(:order, created_by: user.id) }

  it "should create using factory" do
    expect(order).to be_valid
  end

  it "should require user" do
    is_expected.to validate_presence_of(:user_id)
  end

  it "should require created_by" do
    is_expected.to validate_presence_of(:created_by)
  end

  it "should create in new state" do
    expect(order).to be_new
  end

  it "does not allow backdating with future dates" do
    order.ordered_at = 1.day.from_now
    expect(order).to_not be_can_backdate_order_details
  end

  it "does allow backdating with past dates" do
    order.ordered_at = 1.day.ago
    expect(order).to be_can_backdate_order_details
  end

  it { is_expected.to belong_to :order_import }

  context "total cost" do
    let(:account) { create(:nufs_account, account_users_attributes: account_users_attributes_hash(user: user)) }
    let(:facility) { create(:facility) }
    let(:facility_account) { facility.facility_accounts.create(attributes_for(:facility_account)) }
    let(:item) { facility.items.create(attributes_for(:item, facility_account_id: facility_account.id)) }
    let(:order) { user.orders.create(attributes_for(:order, created_by: user.id)) }
    let(:price_group) { FactoryGirl.create(:price_group, facility: facility) }
    let!(:price_policy) { item.item_price_policies.create(attributes_for(:item_price_policy, price_group_id: price_group.id)) }
    let(:user) { create(:user) }

    context "actual" do
      before :each do
        @cost = @subsidy = 0

        (1..4).each do |i|
          cost = 10 * i
          subsidy = 5 * i
          @cost += cost
          @subsidy += subsidy
          order.order_details.create(attributes_for(:order_detail,
                                                    product_id: item.id,
                                                    account_id: account.id,
                                                    actual_cost: cost,
                                                    actual_subsidy: subsidy,
                                                    price_policy_id: price_policy.id,
                                                   ))
        end

        @total = @cost - @subsidy
      end

      it "should have the expected cost" do
        expect(order.cost).to eq @cost
      end

      it "should have the expected subsidy" do
        expect(order.subsidy).to eq @subsidy
      end

      it "should have the expected total" do
        expect(order.total).to eq @total
      end
    end

    context "estimated" do
      before :each do
        @estimated_cost = @estimated_subsidy = 0

        (1..4).each do |i|
          cost = 10 * i
          subsidy = 5 * i
          @estimated_cost += cost
          @estimated_subsidy += subsidy
          order.order_details.create(attributes_for(:order_detail,
                                                    product_id: item.id,
                                                    account_id: account.id,
                                                    estimated_cost: cost,
                                                    estimated_subsidy: subsidy,
                                                    price_policy_id: price_policy.id,
                                                   ))
        end

        @estimated_total = @estimated_cost - @estimated_subsidy
      end

      it "should have the expected estimated_cost" do
        expect(order.estimated_cost).to eq @estimated_cost
      end

      it "should have the expected estimated_subsidy" do
        expect(order.estimated_subsidy).to eq @estimated_subsidy
      end

      it "should have the expected estimated_total" do
        expect(order.estimated_total).to eq @estimated_total
      end
    end
  end

  context "invalidate_order state transition" do
    ## TODO decide what tests need to go here
  end

  context "validate_order state transition" do
    before(:each) do
      @facility = FactoryGirl.create(:facility)
      @facility_account = @facility.facility_accounts.create(FactoryGirl.attributes_for(:facility_account))
      @price_group = FactoryGirl.create(:price_group, facility: @facility)
      @order_status = FactoryGirl.create(:order_status)
      @service      = @facility.services.create(FactoryGirl.attributes_for(:service, initial_order_status_id: @order_status.id, facility_account_id: @facility_account.id))
      @service_pp   = FactoryGirl.create(:service_price_policy, product: @service, price_group: @price_group)
      @user         = FactoryGirl.create(:user)
      @account      = FactoryGirl.create(:nufs_account, account_users_attributes: account_users_attributes_hash(user: @user))
      create(:account_price_group_member, account: @account, price_group: @price_group)
      @order = @user.orders.create(FactoryGirl.attributes_for(:order, created_by: @user.id, account: @account, facility: @facility))
    end

    it "should not validate_order if there are no order_details" do
      expect(@order.validate_order!).to be false
    end

  end

  context "purchase state transition" do
    before(:each) do
      @facility = FactoryGirl.create(:facility)
      @facility_account = @facility.facility_accounts.create(FactoryGirl.attributes_for(:facility_account))
      @price_group  = FactoryGirl.create(:price_group, facility: @facility)
      @order_status = FactoryGirl.create(:order_status)
      @service      = @facility.services.create(FactoryGirl.attributes_for(:service, initial_order_status_id: @order_status.id, facility_account_id: @facility_account.id))
      FactoryGirl.create(:price_group_product, product: @service, price_group: @price_group, reservation_window: nil)
      @service_pp   = FactoryGirl.create(:service_price_policy, product: @service, price_group: @price_group)
      @user         = FactoryGirl.create(:user)
      @account      = FactoryGirl.create(:nufs_account, account_users_attributes: account_users_attributes_hash(user: @user))
      create(:account_price_group_member, account: @account, price_group: @price_group)
      @order = @user.orders.create(FactoryGirl.attributes_for(:order, created_by: @user.id, account: @account, facility: @facility))
    end

    it "should not allow purchase if the state is not :validated" do
      @order.order_details.create(product_id: @service.id, quantity: 1)
      expect(@order.new?).to be true
      @order.save
      expect { @order.purchase! }.to raise_exception AASM::InvalidTransition
    end

    context "successfully moving to purchase" do
      before :each do
        order_attrs = FactoryGirl.attributes_for(:order_detail, product_id: @service.id, quantity: 1, price_policy_id: @service_pp.id, account_id: @account.id, actual_cost: 10, actual_subsidy: 5)
        @order.order_details.create(order_attrs)
        define_open_account(@service.account, @account.account_number)
        expect(@order.validate_order!).to be true
      end
      it "should start off with an empty order status" do
        @order.order_details.all? { |od| expect(od.order_status).to be_nil }
      end
      it "should set the ordered_at" do
        expect(@order.purchase!).to be true
        expect(@order.ordered_at).not_to be_nil
      end
      it "should add to facility.orders collection" do
        expect(@order.purchase!).to be true
        expect(@facility.orders).to eq([@order])
        expect(@facility.order_details.accounts).to eq([@account])
      end
      it "purchase should mark the initial state to the products default" do
        expect(@order.purchase!).to be true
        @order.order_details.all? { |od| expect(od.order_status).to eq(@order_status) }
      end
    end

    it "should check for facility active/inactive changes before purchase" do
      order_attrs = FactoryGirl.attributes_for(:order_detail, product_id: @service.id, quantity: 1, price_policy_id: @service_pp.id, account_id: @account.id, actual_cost: 10, actual_subsidy: 5)
      @order.order_details.create(order_attrs)
      define_open_account(@service.account, @account.account_number)
      expect(@order.validate_order!).to be true

      @facility.is_active = false
      @facility.save!
      @order.reload
      @order.invalidate!
      expect(@order.validate_order!).to be false
    end

    it "should check for product active/inactive changes before purchase" do
      order_attrs = FactoryGirl.attributes_for(:order_detail, product_id: @service.id, quantity: 1, price_policy_id: @service_pp.id, account_id: @account.id, actual_cost: 10, actual_subsidy: 5)
      @order.order_details.create(order_attrs)
      define_open_account(@service.account, @account.account_number)
      expect(@order.validate_order!).to be true

      @service.is_archived = true
      @service.save!
      @order.reload
      @order.invalidate!
      expect(@order.validate_order!).to be false
    end

    it "should check for schedule rule changes before purchase" do
      @instrument    = FactoryGirl.create(:instrument,
                                          facility: @facility,
                                          facility_account: @facility_account)
      @instrument_pp = FactoryGirl.create(:instrument_price_policy, product: @instrument, price_group: @price_group)
      FactoryGirl.create(:price_group_product, product: @instrument, price_group: @price_group)
      # default rule, 9am - 5pm all days
      @rule = @instrument.schedule_rules.create(FactoryGirl.attributes_for(:schedule_rule))
      define_open_account(@instrument.account, @account.account_number)
      @order_detail = @order.order_details.create(product_id: @instrument.id,
                                                  quantity: 1,
                                                  price_policy_id: @instrument_pp.id,
                                                  account_id: @account.id,
                                                  estimated_cost: 10,
                                                  estimated_subsidy: 5,
                                                  created_by: 0)

      @reservation = @instrument.reservations.create(reserve_start_date: Date.today + 1.day,
                                                     reserve_start_hour: 9,
                                                     reserve_start_min: 00,
                                                     reserve_start_meridian: "am",
                                                     duration_value: 60,
                                                     duration_unit: "minutes",
                                                     order_detail: @order_detail,
                                                     split_times: true)
      expect(@order.validate_order!).to be true

      @rule.start_hour = 10
      @rule.save
      @order.reload
      @order.invalidate!
      expect(@order.validate_order!).to be false
    end

  end

  context do # 'add, clear, adjust' do
    before(:each) do
      @facility         = FactoryGirl.create(:facility)
      @facility_account = @facility.facility_accounts.create(FactoryGirl.attributes_for(:facility_account))
      @price_group      = FactoryGirl.create(:price_group, facility: @facility)
      @order_status     = FactoryGirl.create(:order_status)
      @service          = @facility.services.create(FactoryGirl.attributes_for(:service, initial_order_status_id: @order_status.id, facility_account_id: @facility_account.id))
      @service_pp       = FactoryGirl.create(:service_price_policy, product: @service, price_group: @price_group)
      @service_same     = @facility.services.create(FactoryGirl.attributes_for(:service, initial_order_status_id: @order_status.id, facility_account_id: @facility_account.id))
      @service_same_pp  = FactoryGirl.create(:service_price_policy, product: @service_same, price_group: @price_group)

      @facility2         = FactoryGirl.create(:facility)
      @facility_account2 = @facility2.facility_accounts.create(FactoryGirl.attributes_for(:facility_account))
      @price_group2      = FactoryGirl.create(:price_group, facility: @facility2)
      @service2          = @facility2.services.create(FactoryGirl.attributes_for(:service, initial_order_status_id: @order_status.id, facility_account_id: @facility_account2.id))
      @service2_pp       = FactoryGirl.create(:service_price_policy, product: @service2, price_group: @price_group2)

      @user            = FactoryGirl.create(:user)
      @account         = FactoryGirl.create(:nufs_account, account_users_attributes: account_users_attributes_hash(user: @user))
      create(:account_price_group_member, account: @account, price_group: @price_group)
      @cart = @user.orders.create(FactoryGirl.attributes_for(:order, created_by: @user.id, account: @account))

      @item = @facility.items.create(FactoryGirl.attributes_for(:item, facility_account_id: @facility_account.id))
    end

    context "#add" do

      context "bundle" do
        before :each do
          # make a bundle
          @bundle = @facility.bundles.create(FactoryGirl.attributes_for(:bundle, facility_account_id: @facility_account.id))
          @bundle.bundle_products.create!(product: @item, quantity: 4)
          @bundle.bundle_products.create!(product: @service, quantity: 2)

          # add two of them to the cart
          @ods = @cart.add(@bundle, 2)
        end

        it "should add one order_detail per product in the bundle" do
          # should only have as many ods as (# of products in bundle * quantity)
          expect(@ods.size).to eq(@bundle.products.count * 2)

          # shouldn't be missing any products
          expect(@ods.collect(&:product_id) - @bundle.product_ids).to eq([])
        end

        it "should have quantity of each = quantity specified in the bundle * passed in quantity" do
          # check quantities
          @ods.each do |od|
            expect(od.quantity).to eq(@bundle.bundle_products.find_by_product_id(od.product_id).quantity)
          end
        end
      end

      it "should add a single order_detail for an item w/ quantity of 2" do
        ods = @cart.add(@item, 2)
        expect(ods.size).to eq(1)
        expect(ods.first).to be_a_kind_of OrderDetail
      end

      context "service" do
        it "should add two order_details when has an active survey and a quantity of 2" do
          # setup
          @service_w_active_survey = @facility.services.create!(FactoryGirl.attributes_for(:service, initial_order_status_id: @order_status.id, facility_account_id: @facility_account.id))
          allow(@service_w_active_survey).to receive(:active_survey?).and_return(true)

          # doit
          @ods = @cart.add(@service_w_active_survey, 2)

          # asserts
          expect(@ods).to respond_to :each
          expect(@ods.size).to eq(2)
        end

        it "should add two order_details when has an active template and a quantity of 2" do
          # setup
          @service_w_active_template = @facility.services.create(FactoryGirl.attributes_for(:service, initial_order_status_id: @order_status.id, facility_account_id: @facility_account.id))
          @service_w_active_template.stored_files.create! FactoryGirl.attributes_for(:stored_file, file_type: "template", created_by: @user.id)

          # doit
          @ods = @cart.add(@service_w_active_template, 2)

          # asserts
          expect(@ods).to respond_to :each
          expect(@ods.size).to eq(2)
        end

        it "should add one order_detail when has a quantity of 2 and service doesn't have a template or survey" do
          @ods = @cart.add(@service, 2)
          expect(@ods.size).to eq(1)
        end
      end

      it "should add two order_details when product responds to :reservations and quantity = 2" do
        define_purchasable_instrument

        @ods = @cart.add(@instrument, 2)
        expect(@ods.collect(&:product)).to eq([@instrument, @instrument])
        expect(@ods.size).to eq(2)
      end

      it "should have a facility after adding a product to the cart" do
        @cart.add(@service, 1)
        expect(@cart.reload.facility).to eq(@facility)
        expect(@cart.order_details.size).to eq(1)
      end

      it "should throw exception for order_detail from a facility different than the cart" do
        @cart.add(@service, 1)
        expect(@cart.order_details.size).to eq(1)
        expect { @cart.add(@service2, 1) }.to raise_exception NUCore::MixedFacilityCart
        expect(@cart.order_details.size).to eq(1)
      end
    end

    context "clear" do
      it "clear should destroy all order_details and set the cart.facility to nil when clearing cart" do
        @cart.add(@service, 1)
        expect(@cart.reload.facility).to eq(@facility)
        @cart.clear!
        expect(@cart.facility).to be_nil
        expect(@cart.order_details.size).to eq(0)
        expect(@cart.account).to be_nil
        expect(@cart.state).to eq("new")
      end
    end

    context "order detail updates" do
      it "should adjust the quantity" do
        @cart.add(@service, 1)
        @order_detail = @cart.reload.order_details.first
        @cart.update_details(@order_detail.id => { quantity: "2" })
        @order_detail = @cart.reload.order_details.first
        expect(@order_detail.quantity).to eq(2)
      end

      it "should delete the order_detail when setting the quantity to 0" do
        @cart.add(@service, 1)
        @order_detail = @cart.order_details[0]
        @cart.update_details(@order_detail.id => { quantity: "0" })
        expect(@cart.reload.order_details.size).to eq(0)
      end

      it "should adjust the note" do
        @cart.add(@service, 1)
        @order_detail = @cart.reload.order_details.first
        # quantity must be there, or we'll delete the order_detail
        @cart.update_details(@order_detail.id => { quantity: 1, note: "new note value" })
        @order_detail = @cart.reload.order_details.first
        expect(@order_detail.note).to eq("new note value")
      end

      it "should update the child order_details' account on self's account change" do
        @cart.account = @account
        @cart.add(@service, 1)
        @cart.add(@service_same, 1)
        @cart.reload.order_details[0].account_id = @account.id
        @cart.order_details[1].account_id = @account.id
        @account2 = FactoryGirl.create(:nufs_account, account_users_attributes: account_users_attributes_hash(user: @user))
        @cart.account = @account2
        @cart.save
        expect(@cart.reload.order_details[0].account).to eq(@account2)
        expect(@cart.order_details[1].account).to eq(@account2)
        expect(@cart.account).to eq(@account2)
      end

      it "should return an error for invalid quantities" do
        @order_detail = @cart.add(@service, 1).first
        result = @cart.update_details(@order_detail.id => { quantity: "1.5" })
        expect(result).to be false
        expect(@cart.errors).not_to be_empty
        expect(@cart.errors.to_a).to be_include "Quantity must be an integer"
      end

      it "should clear the facility and the account when destroying the last order_detail from the cart" do
        skip
        #        @cart.add(@service, 1)
        #        @cart.add(@service_same, 1)
        #        @cart.order_details[1].destroy
        #        @cart.facility.should_not be_nil
        #        @cart.account.should_not be_nil
        #
        #        @cart.order_details[0].destroy
        #        @cart.facility.should be_nil
        #        @cart.account.should be_nil
      end
    end
  end
  context "ordered_on_behalf_of?" do
    before :each do
      @user = FactoryGirl.create(:user)
      @user2 = FactoryGirl.create(:user)
    end
    it "should be false if it was ordered by the same person" do
      @user.orders.create(FactoryGirl.attributes_for(:order, created_by: @user.id))
      expect(@user.orders.first).not_to be_ordered_on_behalf_of
    end
    it "should be true if it was created by someone else" do
      @user.orders.create(FactoryGirl.attributes_for(:order, created_by: @user2.id))
      expect(@user.orders.first).to be_ordered_on_behalf_of
    end
  end

  context "merge orders" do
    before :each do
      @user  = FactoryGirl.create(:user)
      @order = @user.orders.create(FactoryGirl.attributes_for(:order, created_by: @user.id))
    end

    it "should not be mergeable" do
      expect(@order).not_to be_to_be_merged
      expect(@order.merge_order).to be_nil
    end

    it "should be mergeable" do
      @order2 = @user.orders.create(FactoryGirl.attributes_for(:order, created_by: @user.id, merge_with_order_id: @order.id))
      expect(@order2).to be_to_be_merged
      expect(@order2.merge_order).to eq(@order)
    end
  end

  describe ".for_facility" do
    let(:facilities) { items.map(&:facility) }
    let(:items) { create_list(:setup_item, 2, :with_facility_account) }
    let!(:first_facility_orders) { create_list(:setup_order, 3, product: items.first) }
    let!(:second_facility_orders) { create_list(:setup_order, 3, product: items.second) }

    context "when specifying a facility" do
      it "returns orders for that facility" do
        expect(described_class.for_facility(facilities.first))
          .to match_array(first_facility_orders)
        expect(described_class.for_facility(facilities.second))
          .to match_array(second_facility_orders)
      end
    end

    context "when specifying all facilities" do
      it "returns all orders" do
        expect(described_class.for_facility(Facility.cross_facility))
          .to match_array(first_facility_orders + second_facility_orders)
      end
    end
  end

  describe "#in_cart?" do
    context "when ordered_at is set" do
      subject(:order) { build(:order, ordered_at: Time.zone.now) }

      it { expect(order).not_to be_in_cart }
    end

    context "when ordered_at is not set" do
      subject(:order) { build(:order, ordered_at: nil) }

      it { expect(order).to be_in_cart }
    end
  end
end
