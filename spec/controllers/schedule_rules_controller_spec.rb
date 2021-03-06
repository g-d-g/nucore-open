require "rails_helper"
require "controller_spec_helper"

RSpec.describe ScheduleRulesController do
  render_views

  let(:facility) { @authable }

  before(:all) { create_users }

  before(:each) do
    @authable         = FactoryGirl.create(:facility)
    @facility_account = @authable.facility_accounts.create(FactoryGirl.attributes_for(:facility_account))
    @price_group = FactoryGirl.create(:price_group, facility: facility)
    @instrument       = FactoryGirl.create(:instrument, facility: @authable, facility_account_id: @facility_account.id)
    @price_policy     = @instrument.instrument_price_policies.create(FactoryGirl.attributes_for(:instrument_price_policy).update(price_group_id: @price_group.id))
    expect(@price_policy).to be_valid
    @params = { facility_id: @authable.url_name, instrument_id: @instrument.url_name }
  end

  context "index" do

    before :each do
      @method = :get
      @action = :index
    end

    it_should_allow_operators_only do |_user|
      expect(assigns[:instrument]).to eq(@instrument)
      expect(response).to be_success
      expect(response).to render_template("schedule_rules/index")
    end

  end

  context "new" do

    before :each do
      @method = :get
      @action = :new
    end

    it_should_allow_managers_and_senior_staff_only do
      expect(assigns[:instrument]).to eq(@instrument)
      expect(response).to be_success
      expect(response).to render_template("schedule_rules/new")
    end

  end

  context "create" do

    before :each do
      @method = :post
      @action = :create
      @params.merge!(
        schedule_rule: FactoryGirl.attributes_for(:schedule_rule, instrument_id: @instrument.id),
      )
    end

    it_should_allow_managers_and_senior_staff_only :redirect do
      expect(assigns(:schedule_rule)).to be_kind_of ScheduleRule
      is_expected.to set_flash
      assert_redirected_to facility_instrument_schedule_rules_url(@authable, @instrument)
    end

    context "with restriction levels" do
      before :each do
        @restriction_levels = []
        3.times do
          @restriction_levels << FactoryGirl.create(:product_access_group, product_id: @instrument.id)
        end
        sign_in(@admin)
      end

      it "should come out with no restriction levels" do
        do_request
        expect(assigns[:schedule_rule].product_access_groups).to be_empty
      end

      it "should store restriction_rules" do
        @params.deep_merge!(schedule_rule: { product_access_group_ids: [@restriction_levels[0].id, @restriction_levels[2].id] })
        do_request
        expect(assigns[:schedule_rule].product_access_groups).to contain_all [@restriction_levels[0], @restriction_levels[2]]
        expect(assigns[:schedule_rule].product_access_groups.size).to eq(2)
      end

    end

  end

  context "needs schedule rule" do

    before :each do
      @rule = @instrument.schedule_rules.create(FactoryGirl.attributes_for(:schedule_rule))
      @params.merge!(id: @rule.id)
    end

    context "edit" do

      before :each do
        @method = :get
        @action = :edit
      end

      it_should_allow_managers_and_senior_staff_only do
        expect(assigns(:schedule_rule)).to eq(@rule)
        is_expected.to render_template "edit"
      end

    end

    context "update" do

      before :each do
        @method = :put
        @action = :update
        @params.merge!(
          schedule_rule: FactoryGirl.attributes_for(:schedule_rule),
        )
      end

      it_should_allow_managers_and_senior_staff_only :redirect do
        expect(assigns(:schedule_rule)).to eq(@rule)
        is_expected.to set_flash
        assert_redirected_to facility_instrument_schedule_rules_url(@authable, @instrument)
      end

      context "restriction levels" do
        before :each do
          @restriction_levels = []
          3.times do
            @restriction_levels << FactoryGirl.create(:product_access_group, product_id: @instrument.id)
          end
          sign_in(@admin)
        end

        it "should come out with no restriction levels" do
          do_request
          expect(assigns[:schedule_rule].product_access_groups).to be_empty
        end

        it "should come out with no restriction levels if it had them before" do
          @rule.product_access_groups = @restriction_levels
          @rule.save!
          do_request
          expect(assigns[:schedule_rule].product_access_groups).to be_empty
        end

        it "should store restriction_rules" do
          @params.deep_merge!(schedule_rule: { product_access_group_ids: [@restriction_levels[0].id, @restriction_levels[2].id] })
          do_request
          expect(assigns[:schedule_rule].product_access_groups).to contain_all [@restriction_levels[0], @restriction_levels[2]]
          expect(assigns[:schedule_rule].product_access_groups.size).to eq(2)
        end

      end

    end

    context "destroy" do

      before :each do
        @method = :delete
        @action = :destroy
      end

      it_should_allow_managers_and_senior_staff_only :redirect do
        expect(assigns(:schedule_rule)).to eq(@rule)
        should_be_destroyed @rule
        assert_redirected_to facility_instrument_schedule_rules_url(@authable, @instrument)
      end

    end

  end

end
