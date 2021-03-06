require "rails_helper"

RSpec.describe BulkEmail::ContentGenerator do
  subject { described_class.new(facility) }

  let(:facility) { instrument.facility }
  let(:instrument) { FactoryGirl.create(:setup_instrument, :offline) }
  let(:recipient) { FactoryGirl.build(:user) }

  describe "#greeting" do
    context "without a recipient name" do
      it "generates a greeting with a placeholder name" do
        expect(subject.greeting).to include("Firstname Lastname")
      end
    end

    context "with a recipient name" do
      it "generates a greeting with a placeholder name" do
        expect(subject.greeting(recipient.full_name))
          .to include(recipient.full_name)
      end
    end

    context "with an offline instrument as a subject_product" do
      subject { described_class.new(facility, instrument) }

      it "includes the instrument name with a downtime reason" do
        expect(subject.greeting)
          .to include("#{instrument.name} has been taken offline")
      end
    end
  end

  describe "#signoff" do
    it { expect(subject.signoff).to be_present }
  end

  describe "#subject_prefix" do
    it "includes the app and facility names" do
      expect(subject.subject_prefix)
        .to eq("[#{I18n.t('app_name')} #{facility.name}]")
    end
  end

  describe "#wrap_text" do
    subject { described_class.new(facility, instrument) }

    it "wraps content with the greeting and signoff" do
      expect(subject.wrap_text("This is some text"))
        .to include(subject.greeting)
        .and include("This is some text")
        .and include(subject.signoff)
    end
  end
end
