# frozen_string_literal: true

require "atomic_assessments_import"

RSpec.describe AtomicAssessmentsImport::Questions::ShortAnswer do
  let(:row) do
    {
      "question text" => "What is the chemical symbol for water?",
      "question type" => "short_answer",
      "correct answer" => "H2O",
      "points" => "1",
    }
  end

  describe "#question_type" do
    it "returns shorttext" do
      question = described_class.new(row)
      expect(question.question_type).to eq("shorttext")
    end
  end

  describe "#to_learnosity" do
    it "returns correct structure" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:type]).to eq("shorttext")
      expect(result[:widget_type]).to eq("response")
      expect(result[:data][:stimulus]).to eq("What is the chemical symbol for water?")
    end

    it "includes validation with correct answer" do
      question = described_class.new(row)
      result = question.to_learnosity
      expect(result[:data][:validation][:valid_response][:value]).to eq("H2O")
      expect(result[:data][:validation][:valid_response][:score]).to eq(1)
    end
  end
end
