require "rails_helper"
require "transaction_search_shared_examples"

RSpec.describe TransactionsController do
  let(:params) { {} }
  let(:product) { FactoryGirl.create(:setup_item, :with_facility_account) }
  let(:user) { FactoryGirl.create(:user) }

  describe "GET #in_review" do
    before(:each) do
      sign_in user
      get action, params
    end

    let(:action) { :in_review }

    it_behaves_like TransactionSearch, :fulfilled_at

    context "when the user owns multiple accounts" do
      let!(:accounts) do
        FactoryGirl.create_list(:setup_account,
                                2,
                                :with_order,
                                product: product,
                                owner: user)
      end
      let(:order_details) { accounts.flat_map(&:order_details) }

      before(:each) do
        order_details.each do |order_detail|
          order_detail.reviewed_at = reviewed_at
          order_detail.to_complete!
        end
      end

      context "when reviewed_at is in the future" do
        let(:reviewed_at) { 1.day.from_now }

        it "sets order_details to orders in review from all owned accounts", :aggregate_failures do
          expect(assigns(:order_details)).to match(order_details)
          expect(assigns(:recently_reviewed)).to be_empty
        end
      end

      context "when reviewed_at is in the past" do
        let(:reviewed_at) { 1.day.ago }

        it "sets recently_reviewed to orders reviewed from all owned accounts", :aggregate_failures do
          expect(assigns(:order_details)).to be_empty
          expect(assigns(:recently_reviewed)).to eq(order_details)
        end
      end

    end

  end
end
