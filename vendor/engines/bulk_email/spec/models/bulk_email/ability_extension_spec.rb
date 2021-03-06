require "rails_helper"

RSpec.describe BulkEmail::AbilityExtension do
  subject(:ability) { Ability.new(user, facility, stub_controller) }
  let(:facility) { FactoryGirl.create(:facility) }
  let(:stub_controller) { OpenStruct.new }

  shared_examples_for "it may send bulk email" do
    it { is_expected.to be_allowed_to(:send_bulk_emails, facility) }
  end

  shared_examples_for "it may not send bulk email" do
    it { is_expected.not_to be_allowed_to(:send_bulk_emails, facility) }
  end

  describe "account manager" do
    let(:user) { FactoryGirl.create(:user, :account_manager) }
    it_behaves_like "it may not send bulk email"
  end

  describe "administrator" do
    let(:user) { FactoryGirl.create(:user, :administrator) }
    it_behaves_like "it may send bulk email"
  end

  describe "billing administrator", feature_setting: { billing_administrator: true } do
    let(:user) { FactoryGirl.create(:user, :billing_administrator) }
    it_behaves_like "it may not send bulk email"
  end

  describe "facility administrator" do
    let(:user) { FactoryGirl.create(:user, :facility_administrator, facility: facility) }
    it_behaves_like "it may send bulk email"
  end

  describe "facility director" do
    let(:user) { FactoryGirl.create(:user, :facility_director, facility: facility) }
    it_behaves_like "it may send bulk email"
  end

  describe "senior staff" do
    let(:user) { FactoryGirl.create(:user, :senior_staff, facility: facility) }
    it_behaves_like "it may send bulk email"
  end

  describe "staff" do
    let(:user) { FactoryGirl.create(:user, :staff, facility: facility) }
    it_behaves_like "it may not send bulk email"
  end

  describe "unprivileged user" do
    let(:user) { FactoryGirl.create(:user) }
    it_behaves_like "it may not send bulk email"
  end
end
