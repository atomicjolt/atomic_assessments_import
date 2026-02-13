# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::Ordering do
  let(:row) do
    {
      "question text" => "Arrange these events in chronological order.",
      "question type" => "ordering",
      "option a" => "World War I",
      "option b" => "World War II",
      "option c" => "Cold War",
      "correct answer" => "a; b; c",
      "points" => "3",
    }
  end

  describe "#question_type" do
    it "returns orderlist" do
      question = described_class.new(row)
      expect(question.question_type).to eq("orderlist")
    end
  end

  describe "#to_learnosity" do
    it "has correct list items" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:list]).to eq(["World War I", "World War II", "Cold War"])
    end

    it "includes validation with correct order indices" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:validation][:valid_response][:value]).to eq(["0", "1", "2"])
      expect(result[:data][:validation][:valid_response][:score]).to eq(3)
    end
  end
end
