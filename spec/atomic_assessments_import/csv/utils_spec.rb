# frozen_string_literal: true

RSpec.describe AtomicAssessmentsImport::Utils do
  describe "#parse_boolean" do
    it "returns true for yes" do
      expect(described_class.parse_boolean("yes", default: false)).to be_truthy
    end

    it "returns false for no" do
      expect(described_class.parse_boolean("no", default: false)).to be_falsey
    end

    it "returns default false for nil" do
      expect(described_class.parse_boolean(nil, default: false)).to be_falsey
    end

    it "returns default true for nil" do
      expect(described_class.parse_boolean(nil, default: true)).to be_truthy
    end

    it "returns default true for empty string" do
      expect(described_class.parse_boolean("", default: true)).to be_truthy
    end

    it "returns default false for empty string" do
      expect(described_class.parse_boolean("", default: false)).to be_falsey
    end
  end
end
