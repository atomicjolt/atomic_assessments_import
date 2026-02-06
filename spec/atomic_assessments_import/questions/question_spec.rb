# frozen_string_literal: true

RSpec.describe AtomicAssessmentsImport::Questions::Question do
  describe "#load" do
    it "creates a mcq question" do
      row = CSV::Row.new([:'question type'], ["multiple choice"])
      question = described_class.load(row)
      expect(question).to be_a(AtomicAssessmentsImport::Questions::MultipleChoice)
    end

    it "creates a multiple choice question" do
      row = CSV::Row.new([:'question type'], ["mcq"])
      question = described_class.load(row)
      expect(question).to be_a(AtomicAssessmentsImport::Questions::MultipleChoice)
    end

    it "creates a multiple choice question if no question type is passed" do
      row = CSV::Row.new([:'question type'], [""])
      question = described_class.load(row)
      expect(question).to be_a(AtomicAssessmentsImport::Questions::MultipleChoice)
    end

    it "creates a multiple choice question by default" do
      row = CSV::Row.new([:'question id'], ["123"])
      question = described_class.load(row)
      expect(question).to be_a(AtomicAssessmentsImport::Questions::MultipleChoice)
    end
  end
end
